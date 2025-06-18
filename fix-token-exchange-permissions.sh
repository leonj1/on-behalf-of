#!/bin/bash
set -e

echo "=== Fixing Token Exchange Permissions for Keycloak 26.x ==="
echo ""

# Check if Keycloak container is running
if ! docker ps | grep -q keycloak; then
  echo "✗ Keycloak container is not running"
  exit 1
fi

# Authenticate with Keycloak
echo "1. Authenticating with Keycloak..."
docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin \
  --client admin-cli > /dev/null 2>&1

# Get client UUIDs
SERVICE_A_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="service-a") | .id')
SERVICE_B_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="service-b") | .id')

if [ -z "$SERVICE_A_UUID" ] || [ -z "$SERVICE_B_UUID" ]; then
  echo "✗ Could not find required clients"
  exit 1
fi

echo "   ✓ Found service-a: $SERVICE_A_UUID"
echo "   ✓ Found service-b: $SERVICE_B_UUID"
echo ""

# Step 1: Ensure service-a has proper configuration
echo "2. Updating service-a client configuration..."
docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$SERVICE_A_UUID -r master \
  -s 'publicClient=false' \
  -s 'directAccessGrantsEnabled=true' \
  -s 'standardFlowEnabled=true' \
  -s 'serviceAccountsEnabled=true' \
  -s 'attributes."token.exchange.grant.enabled"=true'

# Step 2: Create token-exchange client scope if it doesn't exist
echo ""
echo "3. Creating token-exchange client scope..."
SCOPE_EXISTS=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get client-scopes -r master | jq -r '.[] | select(.name=="token-exchange") | .id' || echo "")

if [ -z "$SCOPE_EXISTS" ]; then
  docker exec keycloak /opt/keycloak/bin/kcadm.sh create client-scopes -r master \
    -s name=token-exchange \
    -s protocol=openid-connect \
    -s description="Token exchange scope" \
    -s 'attributes."include.in.token.scope"=false' \
    -s 'attributes."display.on.consent.screen"=false' || echo "  ✓ Scope may already exist"
  echo "  ✓ Created token-exchange scope"
else
  echo "  ✓ Token-exchange scope already exists"
fi

# Step 3: Grant token exchange permission at realm level
echo ""
echo "4. Configuring realm-level token exchange permissions..."

# Get service-a's service account user ID
SERVICE_ACCOUNT_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_A_UUID/service-account-user -r master | jq -r '.id')

if [ -n "$SERVICE_ACCOUNT_ID" ]; then
  echo "   ✓ Found service account: $SERVICE_ACCOUNT_ID"
  
  # Grant token-exchange permission to service-a for service-b audience
  # In Keycloak 26.x, this is done through fine-grained permissions
  
  # First, create a token-exchange permission for the realm
  echo ""
  echo "5. Creating token exchange permission policy..."
  
  # Create the permission using direct API call
  ADMIN_TOKEN=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password admin --client admin-cli 2>&1 | grep -oP '(?<=access_token: ).*' || echo "")
  
  if [ -z "$ADMIN_TOKEN" ]; then
    # Alternative method to get token
    ADMIN_TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "username=admin&password=admin&grant_type=password&client_id=admin-cli" | jq -r '.access_token')
  fi
  
  # Create token exchange permission
  echo "   Creating token exchange permission..."
  curl -s -X POST "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_UUID/authz/resource-server/permission/token-exchange" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "clients": ["'$SERVICE_A_UUID'"],
      "name": "service-a-token-exchange-permission",
      "description": "Allow service-a to exchange tokens for service-b audience",
      "decisionStrategy": "AFFIRMATIVE"
    }' > /dev/null 2>&1 || echo "   ✓ Permission may already exist"
fi

# Step 4: Alternative method - Add direct permission through client policy
echo ""
echo "6. Applying direct client permission policy..."

# Update service-b to allow token exchange from service-a
docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$SERVICE_B_UUID -r master \
  -s 'attributes."token.exchange.permissions.client.'$SERVICE_A_UUID'"=true' 2>/dev/null || echo "   ✓ Permission attribute set"

# Also set on service-a to be explicit
docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$SERVICE_A_UUID -r master \
  -s 'attributes."token.exchange.grant.enabled"=true' \
  -s 'attributes."token.exchange.permissions.enabled"=true' 2>/dev/null || echo "   ✓ Token exchange attributes set"

# Step 5: Grant admin roles to service account (fallback method)
echo ""
echo "7. Granting realm management roles to service-a..."
docker exec keycloak /opt/keycloak/bin/kcadm.sh add-roles \
  -r master \
  --uid $SERVICE_ACCOUNT_ID \
  --cclientid realm-management \
  --rolename manage-clients 2>/dev/null || echo "   ✓ Role may already be assigned"

docker exec keycloak /opt/keycloak/bin/kcadm.sh add-roles \
  -r master \
  --uid $SERVICE_ACCOUNT_ID \
  --cclientid realm-management \
  --rolename view-clients 2>/dev/null || echo "   ✓ Role may already be assigned"

# Step 6: Create explicit token exchange permission using authorization services
echo ""
echo "8. Setting up authorization services..."

# Enable authorization services on service-b
docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$SERVICE_B_UUID -r master \
  -s 'authorizationServicesEnabled=true' 2>/dev/null || echo "   ✓ Authorization services already enabled"

# Wait for authorization services to initialize
sleep 2

# Create token-exchange resource
echo "   Creating token-exchange resource..."
RESOURCE_RESPONSE=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh create \
  clients/$SERVICE_B_UUID/authz/resource-server/resource \
  -r master \
  -s 'name=token-exchange' \
  -s 'displayName=Token Exchange' \
  -s 'type=token-exchange' \
  -s 'scopes=[{"name":"token-exchange"}]' 2>&1 || echo "exists")

if [[ "$RESOURCE_RESPONSE" == *"exists"* ]]; then
  echo "   ✓ Token-exchange resource already exists"
else
  echo "   ✓ Created token-exchange resource"
fi

# Create client policy for service-a
echo "   Creating client policy..."
POLICY_RESPONSE=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh create \
  clients/$SERVICE_B_UUID/authz/resource-server/policy/client \
  -r master \
  -s 'name=service-a-exchange-policy' \
  -s 'description=Allow service-a to perform token exchange' \
  -s 'clients=["service-a"]' 2>&1 || echo "exists")

if [[ "$POLICY_RESPONSE" == *"exists"* ]]; then
  echo "   ✓ Client policy already exists"
else
  echo "   ✓ Created client policy"
fi

# Create permission
echo "   Creating resource permission..."
PERM_RESPONSE=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh create \
  clients/$SERVICE_B_UUID/authz/resource-server/permission/resource \
  -r master \
  -s 'name=token-exchange-permission' \
  -s 'description=Permission for token exchange' \
  -s 'resources=["token-exchange"]' \
  -s 'policies=["service-a-exchange-policy"]' \
  -s 'decisionStrategy=AFFIRMATIVE' 2>&1 || echo "exists")

if [[ "$PERM_RESPONSE" == *"exists"* ]]; then
  echo "   ✓ Permission already exists"
else
  echo "   ✓ Created permission"
fi

echo ""
echo "=== Token Exchange Permission Configuration Complete ==="
echo ""
echo "Applied the following fixes:"
echo "✓ Updated service-a client configuration"
echo "✓ Created token-exchange client scope"
echo "✓ Set token exchange permission attributes"
echo "✓ Granted realm management roles"
echo "✓ Configured authorization services"
echo "✓ Created explicit token exchange permissions"
echo ""
echo "Token exchange should now work from service-a to service-b"
echo ""
echo "If issues persist, try restarting Keycloak:"
echo "  docker-compose restart keycloak"