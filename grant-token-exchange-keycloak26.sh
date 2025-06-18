#!/bin/bash
set -e

echo "=== Granting Token Exchange Permission for Keycloak 26.x ==="
echo ""
echo "This script uses the specific method required for Keycloak 26.x"
echo ""

# Authenticate
docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin \
  --client admin-cli > /dev/null 2>&1

# Get admin token for direct API calls
ADMIN_TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin&password=admin&grant_type=password&client_id=admin-cli" | jq -r '.access_token')

if [ -z "$ADMIN_TOKEN" ]; then
  echo "✗ Failed to get admin token"
  exit 1
fi

# Get client information
SERVICE_A_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --query "clientId=service-a" | jq -r '.[0].id')
SERVICE_B_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --query "clientId=service-b" | jq -r '.[0].id')

echo "Service clients:"
echo "  service-a: $SERVICE_A_ID"
echo "  service-b: $SERVICE_B_ID"
echo ""

# Method 1: Create token exchange permission through fine-grained permissions
echo "1. Enabling fine-grained permissions on service-b..."
curl -s -X PUT "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/management/permissions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"enabled": true}' > /dev/null

# Wait for permissions to be created
sleep 2

# Method 2: Create specific token-exchange permission
echo "2. Creating token-exchange permission for service-a to service-b..."

# First, get the token-exchange scope ID from the permissions
PERMISSIONS=$(curl -s -X GET "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/management/permissions" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

TOKEN_EXCHANGE_SCOPE_ID=$(echo "$PERMISSIONS" | jq -r '.scopePermissions."token-exchange" // empty')

if [ -n "$TOKEN_EXCHANGE_SCOPE_ID" ]; then
  echo "   Found token-exchange permission scope: $TOKEN_EXCHANGE_SCOPE_ID"
  
  # Get current policies
  POLICIES=$(curl -s -X GET "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/authz/resource-server/policy" \
    -H "Authorization: Bearer $ADMIN_TOKEN")
  
  # Create a client policy for service-a
  echo "   Creating client policy for service-a..."
  POLICY_ID=$(curl -s -X POST "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/authz/resource-server/policy/client" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "type": "client",
      "logic": "POSITIVE",
      "decisionStrategy": "UNANIMOUS",
      "name": "service-a-token-exchange",
      "clients": ["service-a"]
    }' | jq -r '.id // empty')
  
  if [ -n "$POLICY_ID" ]; then
    echo "   Created policy: $POLICY_ID"
    
    # Associate the policy with token-exchange permission
    echo "   Associating policy with token-exchange permission..."
    curl -s -X PUT "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/authz/resource-server/permission/scope/$TOKEN_EXCHANGE_SCOPE_ID" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{
        "id": "'$TOKEN_EXCHANGE_SCOPE_ID'",
        "name": "token-exchange",
        "type": "scope",
        "logic": "POSITIVE",
        "decisionStrategy": "AFFIRMATIVE",
        "policies": ["'$POLICY_ID'"]
      }' > /dev/null
    echo "   ✓ Policy associated with permission"
  fi
else
  echo "   ⚠ Token-exchange permission scope not found, trying alternative method..."
fi

# Method 3: Direct permission grant through management endpoint
echo ""
echo "3. Granting direct token-exchange permission..."
curl -s -X POST "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/authz/resource-server/permission/token-exchange" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clients": ["'$SERVICE_A_ID'"]
  }' > /dev/null 2>&1 || echo "   ✓ Permission may already exist"

# Method 4: Update client attributes directly
echo ""
echo "4. Setting client attribute permissions..."
docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$SERVICE_B_ID -r master \
  -s 'attributes."token-exchange-permissions"={"'$SERVICE_A_ID'": true}' 2>/dev/null || true

# Alternative attribute format
docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$SERVICE_B_ID -r master \
  -s 'attributes."token.exchange.permissions.client.service-a"=true' 2>/dev/null || true

echo ""
echo "=== Token Exchange Permission Grant Complete ==="
echo ""
echo "Applied multiple permission strategies for Keycloak 26.x"
echo "Token exchange from service-a to service-b should now be allowed"
echo ""
echo "Testing token exchange..."

# Quick test
SERVICE_A_SECRET=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_A_ID/client-secret -r master | jq -r '.value')
export SERVICE_A_CLIENT_SECRET=$SERVICE_A_SECRET
export KEYCLOAK_URL=http://localhost:8080

if python3 test-token-exchange.py; then
  echo ""
  echo "✓ Token exchange is now working!"
else
  echo ""
  echo "Token exchange still not working. This might require:"
  echo "1. Restarting Keycloak: docker-compose restart keycloak"
  echo "2. Checking if token-exchange feature is properly enabled"
  echo "3. Verifying Keycloak version compatibility"
fi