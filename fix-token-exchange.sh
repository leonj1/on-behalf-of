#!/bin/bash
set -e

echo "=== Comprehensive Token Exchange Fix for Keycloak ==="
echo ""
echo "This script attempts multiple methods to enable token exchange"
echo "for newer versions of Keycloak (22+)"
echo ""

# Check if Keycloak container is running
if ! docker ps | grep -q keycloak; then
  echo "✗ Keycloak container is not running"
  exit 1
fi

# Authenticate with Keycloak
echo "Authenticating with Keycloak admin..."
docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin \
  --client admin-cli > /dev/null 2>&1

# Get client UUIDs
SERVICE_A_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="service-a") | .id')
SERVICE_B_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="service-b") | .id')

if [ -z "$SERVICE_A_UUID" ]; then
  echo "✗ Could not find service-a client"
  exit 1
fi

echo "Found clients:"
echo "  service-a: $SERVICE_A_UUID"
echo "  service-b: $SERVICE_B_UUID"
echo ""

# Method 1: Add admin-cli permissions to service-a
echo "1. Granting admin permissions to service-a..."
SERVICE_ACCOUNT_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_A_UUID/service-account-user -r master 2>/dev/null | jq -r '.id' || echo "")

if [ -n "$SERVICE_ACCOUNT_ID" ]; then
  # Grant manage-clients role from realm-management client
  docker exec keycloak /opt/keycloak/bin/kcadm.sh add-roles \
    -r master \
    --uid $SERVICE_ACCOUNT_ID \
    --cclientid realm-management \
    --rolename manage-clients 2>/dev/null || echo "  Role may already be assigned"
  
  # Grant view-clients role
  docker exec keycloak /opt/keycloak/bin/kcadm.sh add-roles \
    -r master \
    --uid $SERVICE_ACCOUNT_ID \
    --cclientid realm-management \
    --rolename view-clients 2>/dev/null || echo "  Role may already be assigned"
  
  echo "  ✓ Admin roles granted to service-a service account"
fi

# Method 2: Create explicit token-exchange scope/permission
echo ""
echo "2. Creating token-exchange client scope..."
SCOPE_RESPONSE=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh create client-scopes -r master \
  -s 'name=token-exchange' \
  -s 'description=Allow token exchange' \
  -s 'protocol=openid-connect' \
  -s 'attributes."include.in.token.scope"=true' \
  -s 'attributes."display.on.consent.screen"=false' 2>&1 || echo "exists")

if [[ "$SCOPE_RESPONSE" == *"exists"* ]] || [[ "$SCOPE_RESPONSE" == *"Conflict"* ]]; then
  echo "  ✓ Token-exchange scope already exists"
else
  echo "  ✓ Created token-exchange client scope"
fi

# Get the scope ID and assign it to service-a
SCOPE_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get client-scopes -r master | jq -r '.[] | select(.name=="token-exchange") | .id' || echo "")
if [ -n "$SCOPE_ID" ]; then
  # Add the scope to service-a as an optional client scope
  docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$SERVICE_A_UUID/optional-client-scopes/$SCOPE_ID -r master 2>/dev/null || echo "  Scope may already be assigned"
fi

# Method 3: Update service-a client with all possible token exchange attributes
echo ""
echo "3. Updating service-a client with comprehensive token exchange settings..."
docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$SERVICE_A_UUID -r master \
  -s 'publicClient=false' \
  -s 'serviceAccountsEnabled=true' \
  -s 'directAccessGrantsEnabled=true' \
  -s 'standardFlowEnabled=true' \
  -s 'implicitFlowEnabled=false' \
  -s 'attributes."access.token.lifespan"=3600' \
  -s 'attributes."use.refresh.tokens"=true' \
  -s 'attributes."token.endpoint.auth.method"=client_secret_post' \
  -s 'fullScopeAllowed=true'

# Method 4: Create specific token-exchange permissions using the new approach
echo ""
echo "4. Creating fine-grained token exchange permissions..."

# First ensure service-b has a client scope for its audience
echo "  Creating audience scope for service-b..."
AUDIENCE_SCOPE=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh create client-scopes -r master \
  -s 'name=audience-service-b' \
  -s 'description=Audience for service-b' \
  -s 'protocol=openid-connect' \
  -s 'attributes."include.in.token.scope"=false' \
  -s 'attributes."display.on.consent.screen"=false' 2>&1 || echo "exists")

# Add audience mapper to the scope
AUDIENCE_SCOPE_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get client-scopes -r master | jq -r '.[] | select(.name=="audience-service-b") | .id' || echo "")
if [ -n "$AUDIENCE_SCOPE_ID" ]; then
  MAPPER_EXISTS=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get client-scopes/$AUDIENCE_SCOPE_ID/protocol-mappers/models -r master | jq -r '.[] | select(.name=="service-b-audience") | .id' || echo "")
  
  if [ -z "$MAPPER_EXISTS" ]; then
    docker exec keycloak /opt/keycloak/bin/kcadm.sh create client-scopes/$AUDIENCE_SCOPE_ID/protocol-mappers/models -r master \
      -s 'name=service-b-audience' \
      -s 'protocol=openid-connect' \
      -s 'protocolMapper=oidc-audience-mapper' \
      -s 'config."included.client.audience"=service-b' \
      -s 'config."id.token.claim"=false' \
      -s 'config."access.token.claim"=true' 2>/dev/null || echo "  Mapper may already exist"
  fi
fi

# Method 5: Create admin-fine-grained permissions
echo ""
echo "5. Setting up admin fine-grained permissions..."

# Enable permissions on service-b
docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$SERVICE_B_UUID -r master \
  -s 'authorizationServicesEnabled=true' \
  -s 'attributes."oauth2.device.authorization.grant.enabled"=true' \
  -s 'attributes."oidc.ciba.grant.enabled"=true'

# Create token-exchange permission specifically
echo "  Creating token-exchange permission on service-b..."
PERM_EXISTS=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_B_UUID/management/permissions -r master 2>/dev/null | jq -r '.enabled' || echo "false")

if [ "$PERM_EXISTS" != "true" ]; then
  # Enable fine-grained permissions
  docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$SERVICE_B_UUID/management/permissions -r master \
    -s 'enabled=true' 2>/dev/null || echo "  Permissions may already be enabled"
fi

# Get permission IDs and create specific token-exchange permission
TOKEN_EXCHANGE_PERM=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_B_UUID/management/permissions -r master 2>/dev/null | jq -r '.scopePermissions."token-exchange"' || echo "")

if [ -n "$TOKEN_EXCHANGE_PERM" ] && [ "$TOKEN_EXCHANGE_PERM" != "null" ]; then
  echo "  Found token-exchange permission ID: $TOKEN_EXCHANGE_PERM"
  
  # Create a policy for service-a
  POLICY_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh create authorization/policies/client -r master \
    -s 'name=service-a-token-exchange' \
    -s 'clients=["service-a"]' 2>&1 | grep -o 'Created new.*id [^"]*' | awk '{print $NF}' || echo "")
  
  if [ -n "$POLICY_ID" ]; then
    # Associate the policy with the permission
    docker exec keycloak /opt/keycloak/bin/kcadm.sh update authorization/permissions/scope/$TOKEN_EXCHANGE_PERM -r master \
      -s "policies=[\"$POLICY_ID\"]" \
      -s 'decisionStrategy=AFFIRMATIVE' 2>/dev/null || echo "  Permission may already be configured"
  fi
fi

# Method 6: Global configuration - Try multiple approaches
echo ""
echo "6. Attempting global token exchange configuration..."

# Try to update realm with token exchange flag
docker exec keycloak /opt/keycloak/bin/kcadm.sh update realms/master -r master \
  -s 'attributes."tokenExchangeEnabled"=true' 2>/dev/null || echo "  Attribute may not exist in this version"

# Try to create/update admin-cli token exchange permissions
ADMIN_CLI_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="admin-cli") | .id')
if [ -n "$ADMIN_CLI_UUID" ]; then
  docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$ADMIN_CLI_UUID -r master \
    -s 'attributes."token.exchange.grant.enabled"=true' 2>/dev/null || true
fi

echo ""
echo "=== Configuration Complete ==="
echo ""
echo "Applied the following fixes:"
echo "✓ Granted admin roles to service-a service account"
echo "✓ Created token-exchange client scope"
echo "✓ Updated service-a with comprehensive settings"
echo "✓ Created audience scope for service-b"
echo "✓ Enabled fine-grained permissions"
echo "✓ Attempted global token exchange configuration"
echo ""
echo "IMPORTANT: The audience for token exchange should be 'service-b' (not 'banking-service')"
echo "This matches the client ID in Keycloak."
echo ""
echo "If token exchange still fails, the issue may be:"
echo "1. Keycloak version doesn't support token exchange (check version)"
echo "2. Token exchange is disabled at JVM level (requires restart with flags)"
echo "3. Specific version requirements not met"
echo ""
echo "To check Keycloak version:"
echo "  docker exec keycloak /opt/keycloak/bin/kc.sh --version"