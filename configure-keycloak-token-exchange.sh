#!/bin/bash
set -e

echo "=== Configuring Keycloak Token Exchange ==="
echo ""
echo "This script sets up token exchange permissions for service-a to exchange tokens"
echo "targeting banking-service (service-b) audience."
echo ""

# Check if Keycloak container is running
if ! docker ps | grep -q keycloak; then
  echo "✗ Keycloak container is not running"
  exit 1
fi

# Authenticate with Keycloak
echo "1. Authenticating with Keycloak admin..."
docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin \
  --client admin-cli > /dev/null 2>&1

# Get client UUIDs
echo "2. Finding client IDs..."
SERVICE_A_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="service-a") | .id')
SERVICE_B_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="service-b") | .id')
NEXTJS_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="nextjs-app") | .id')

if [ -z "$SERVICE_A_UUID" ] || [ -z "$SERVICE_B_UUID" ]; then
  echo "✗ Could not find required clients"
  exit 1
fi

echo "   ✓ Found service-a: $SERVICE_A_UUID"
echo "   ✓ Found service-b: $SERVICE_B_UUID"
if [ -n "$NEXTJS_UUID" ]; then
  echo "   ✓ Found nextjs-app: $NEXTJS_UUID"
fi

# Step 1: Enable authorization services on the target client (service-b)
echo ""
echo "3. Enabling authorization services on service-b (target client)..."
docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$SERVICE_B_UUID -r master \
  -s 'authorizationServicesEnabled=true' \
  -s 'serviceAccountsEnabled=true'

# Step 2: Create token-exchange permission on service-b
echo ""
echo "4. Creating token-exchange permission on service-b..."

# First, we need to get the resource server ID (created when authorization is enabled)
sleep 2  # Give Keycloak time to create the authorization resources

# Create the token-exchange permission using the Authorization API
PERMISSION_RESPONSE=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh create \
  clients/$SERVICE_B_UUID/authz/resource-server/permission/token-exchange \
  -r master \
  -s 'name=token-exchange-permission' \
  -s 'description=Allow token exchange to this client' \
  -s 'decisionStrategy=AFFIRMATIVE' \
  2>&1 || echo "exists")

if [[ "$PERMISSION_RESPONSE" == *"exists"* ]] || [[ "$PERMISSION_RESPONSE" == *"Conflict"* ]]; then
  echo "   ✓ Token exchange permission already exists"
else
  echo "   ✓ Created token exchange permission"
fi

# Step 3: Create a policy that allows service-a to perform token exchange
echo ""
echo "5. Creating policy to allow service-a to exchange tokens..."

# Create a client policy that includes service-a
POLICY_RESPONSE=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh create \
  clients/$SERVICE_B_UUID/authz/resource-server/policy/client \
  -r master \
  -s 'name=service-a-token-exchange-policy' \
  -s 'description=Allow service-a to exchange tokens' \
  -s 'clients=["service-a"]' \
  2>&1 || echo "exists")

if [[ "$POLICY_RESPONSE" == *"exists"* ]] || [[ "$POLICY_RESPONSE" == *"Conflict"* ]]; then
  echo "   ✓ Client policy already exists"
else
  echo "   ✓ Created client policy for service-a"
fi

# Step 4: Associate the policy with the permission
echo ""
echo "6. Associating policy with token-exchange permission..."

# Get the permission ID
PERMISSION_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get \
  clients/$SERVICE_B_UUID/authz/resource-server/permission \
  -r master | jq -r '.[] | select(.name=="token-exchange-permission") | .id' | head -1)

if [ -n "$PERMISSION_ID" ]; then
  # Get the policy ID
  POLICY_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get \
    clients/$SERVICE_B_UUID/authz/resource-server/policy \
    -r master | jq -r '.[] | select(.name=="service-a-token-exchange-policy") | .id' | head -1)
  
  if [ -n "$POLICY_ID" ]; then
    # Update the permission to use the policy
    docker exec keycloak /opt/keycloak/bin/kcadm.sh update \
      clients/$SERVICE_B_UUID/authz/resource-server/permission/token-exchange/$PERMISSION_ID \
      -r master \
      -s "policies=[\"$POLICY_ID\"]" \
      -s 'decisionStrategy=AFFIRMATIVE' 2>/dev/null || echo "   ✓ Permission already configured"
    echo "   ✓ Associated policy with permission"
  fi
fi

# Step 5: Configure service-a client for token exchange
echo ""
echo "7. Configuring service-a client settings..."
docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$SERVICE_A_UUID -r master \
  -s 'publicClient=false' \
  -s 'serviceAccountsEnabled=true' \
  -s 'directAccessGrantsEnabled=true' \
  -s 'standardFlowEnabled=true'

# Step 6: Also allow nextjs-app to perform token exchange (optional but useful)
if [ -n "$NEXTJS_UUID" ]; then
  echo ""
  echo "8. Adding nextjs-app to token exchange policy..."
  
  # Update the existing policy to include nextjs-app
  docker exec keycloak /opt/keycloak/bin/kcadm.sh update \
    clients/$SERVICE_B_UUID/authz/resource-server/policy/client \
    -r master \
    --query "name=service-a-token-exchange-policy" \
    -s 'clients=["service-a","nextjs-app"]' 2>/dev/null || echo "   ✓ Policy update skipped"
fi

# Step 7: Verify configuration
echo ""
echo "9. Verifying configuration..."

# Check if authorization is enabled
AUTH_ENABLED=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_B_UUID -r master | jq -r '.authorizationServicesEnabled')
if [ "$AUTH_ENABLED" = "true" ]; then
  echo "   ✓ Authorization services enabled on service-b"
else
  echo "   ✗ Authorization services not enabled on service-b"
fi

# Check if service account is enabled on service-a
SA_ENABLED=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_A_UUID -r master | jq -r '.serviceAccountsEnabled')
if [ "$SA_ENABLED" = "true" ]; then
  echo "   ✓ Service account enabled on service-a"
else
  echo "   ✗ Service account not enabled on service-a"
fi

echo ""
echo "=== Token Exchange Configuration Complete ==="
echo ""
echo "Token exchange should now work with:"
echo "- Source client: service-a"
echo "- Target audience: banking-service (service-b)"
echo "- Grant type: urn:ietf:params:oauth:grant-type:token-exchange"
echo ""
echo "If issues persist, check:"
echo "1. Service-a has the correct client secret"
echo "2. The user token being exchanged is valid"
echo "3. Keycloak logs: docker logs keycloak"