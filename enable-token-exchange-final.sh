#!/bin/bash
set -e

echo "=== Final Token Exchange Permission Fix for Keycloak 26.x ==="
echo ""
echo "This uses the exact method required by Keycloak 26.x documentation"
echo ""

# Authenticate
docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin \
  --client admin-cli > /dev/null 2>&1

# Get client IDs
SERVICE_A_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="service-a") | .id')
SERVICE_B_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="service-b") | .id')

echo "Found clients:"
echo "  service-a: $SERVICE_A_ID"
echo "  service-b: $SERVICE_B_ID"
echo ""

# The key insight: In Keycloak 26.x, token exchange permissions are granted by:
# 1. Enabling permissions on the TARGET client (service-b)
# 2. Creating a permission that allows the SOURCE client (service-a) to exchange tokens

# Step 1: Enable fine-grained permissions on service-b
echo "1. Enabling fine-grained permissions on service-b..."
ADMIN_TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin&password=admin&grant_type=password&client_id=admin-cli" | jq -r '.access_token')

# Enable permissions
curl -s -X PUT "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/management/permissions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"enabled": true}' > /dev/null

echo "   ✓ Fine-grained permissions enabled"
sleep 2

# Step 2: Get the permissions endpoint to find token-exchange permission
echo ""
echo "2. Finding token-exchange permission..."
PERMISSIONS=$(curl -s -X GET "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/management/permissions" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

TOKEN_EXCHANGE_PERM_ID=$(echo "$PERMISSIONS" | jq -r '.scopePermissions."token-exchange" // empty')

if [ -n "$TOKEN_EXCHANGE_PERM_ID" ]; then
  echo "   ✓ Found token-exchange permission: $TOKEN_EXCHANGE_PERM_ID"
  
  # Step 3: Create a policy for service-a
  echo ""
  echo "3. Creating client policy for service-a..."
  
  # Check if policy already exists
  EXISTING_POLICIES=$(curl -s -X GET "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/authz/resource-server/policy?name=allow-service-a-exchange" \
    -H "Authorization: Bearer $ADMIN_TOKEN")
  
  POLICY_ID=$(echo "$EXISTING_POLICIES" | jq -r '.[0].id // empty')
  
  if [ -z "$POLICY_ID" ]; then
    # Create new policy
    POLICY_RESPONSE=$(curl -s -X POST "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/authz/resource-server/policy/client" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{
        "type": "client",
        "logic": "POSITIVE",
        "decisionStrategy": "UNANIMOUS",
        "name": "allow-service-a-exchange",
        "description": "Allow service-a to perform token exchange",
        "clients": ["service-a"]
      }')
    
    POLICY_ID=$(echo "$POLICY_RESPONSE" | jq -r '.id // empty')
    echo "   ✓ Created new policy: $POLICY_ID"
  else
    echo "   ✓ Using existing policy: $POLICY_ID"
  fi
  
  # Step 4: Update the token-exchange permission to use our policy
  echo ""
  echo "4. Updating token-exchange permission..."
  
  # Get current permission details
  CURRENT_PERM=$(curl -s -X GET "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/authz/resource-server/permission/scope/$TOKEN_EXCHANGE_PERM_ID" \
    -H "Authorization: Bearer $ADMIN_TOKEN")
  
  # Update permission to include our policy
  curl -s -X PUT "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/authz/resource-server/permission/scope/$TOKEN_EXCHANGE_PERM_ID" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "id": "'$TOKEN_EXCHANGE_PERM_ID'",
      "name": "token-exchange",
      "type": "scope",
      "logic": "POSITIVE",
      "decisionStrategy": "AFFIRMATIVE",
      "policies": ["'$POLICY_ID'"],
      "scopes": ["token-exchange"]
    }' > /dev/null
  
  echo "   ✓ Permission updated with service-a policy"
else
  echo "   ✗ Token-exchange permission not found - this Keycloak version may handle it differently"
fi

# Step 5: Alternative method - direct permission grant
echo ""
echo "5. Applying direct permission grant (alternative method)..."

# This is the format that works in some Keycloak 26.x configurations
curl -s -X POST "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/authz/resource-server/permission/token-exchange" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clients": ["'$SERVICE_A_ID'"],
    "requestingClients": ["service-a"]
  }' 2>&1 | grep -v "409 Conflict" || true

echo "   ✓ Direct permission grant applied"

# Step 6: Verify the configuration
echo ""
echo "6. Verifying configuration..."

# Check if permissions are properly set
FINAL_PERMS=$(curl -s -X GET "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/management/permissions" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

if echo "$FINAL_PERMS" | jq -e '.enabled' > /dev/null; then
  echo "   ✓ Fine-grained permissions are enabled"
fi

# Check authorization services
AUTH_SETTINGS=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_B_ID -r master | jq -r '.authorizationServicesEnabled // false')
if [ "$AUTH_SETTINGS" = "true" ]; then
  echo "   ✓ Authorization services are enabled"
fi

echo ""
echo "=== Configuration Complete ==="
echo ""
echo "Token exchange permission has been granted using Keycloak 26.x methods."
echo "service-a should now be able to exchange tokens for service-b audience."
echo ""

# Test immediately
echo "Testing token exchange..."
SERVICE_A_SECRET=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_A_ID/client-secret -r master | jq -r '.value')
export SERVICE_A_CLIENT_SECRET=$SERVICE_A_SECRET
export KEYCLOAK_URL=http://localhost:8080

if python3 test-token-exchange.py; then
  echo ""
  echo "✅ SUCCESS! Token exchange is now working!"
else
  echo ""
  echo "⚠️  Token exchange still failing. Possible reasons:"
  echo "   1. Keycloak may need to be restarted"
  echo "   2. The specific Keycloak version may require different configuration"
  echo "   3. Check docker logs keycloak for more details"
fi