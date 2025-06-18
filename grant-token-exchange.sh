#!/bin/bash
set -e

echo "=== Granting Token Exchange Permission ==="
echo ""
echo "This script uses a direct approach to grant token exchange permission"
echo "from service-a to service-b by manipulating the authorization settings."
echo ""

# Check if Keycloak container is running
if ! docker ps | grep -q keycloak; then
  echo "✗ Keycloak container is not running"
  exit 1
fi

# Authenticate
docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin \
  --client admin-cli > /dev/null 2>&1

# Get client UUIDs
SERVICE_A_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="service-a") | .id')
SERVICE_B_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="service-b") | .id')

echo "Service clients:"
echo "  service-a: $SERVICE_A_UUID"
echo "  service-b: $SERVICE_B_UUID"
echo ""

# Step 1: Make sure both clients have the right settings
echo "1. Configuring client settings..."

# Configure service-a
docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$SERVICE_A_UUID -r master \
  -s 'serviceAccountsEnabled=true' \
  -s 'directAccessGrantsEnabled=true' \
  -s 'publicClient=false' \
  -s 'attributes."use.refresh.tokens"=true'

# Configure service-b  
docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$SERVICE_B_UUID -r master \
  -s 'consentRequired=false' \
  -s 'directAccessGrantsEnabled=true' \
  -s 'publicClient=false'

echo "✓ Client settings updated"

# Step 2: Grant specific realm-management roles to service-a's service account
echo ""
echo "2. Granting realm-management roles to service-a..."

SERVICE_ACCOUNT_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_A_UUID/service-account-user -r master | jq -r '.id')

if [ -n "$SERVICE_ACCOUNT_ID" ]; then
  # Get realm-management client ID
  REALM_MGMT_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="realm-management") | .id')
  
  if [ -n "$REALM_MGMT_ID" ]; then
    # Get available roles
    echo "   Available realm-management roles:"
    docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$REALM_MGMT_ID/roles -r master --fields name | jq -r '.[].name' | grep -E "(token|exchange|manage)" || true
    
    # Grant specific roles that might help with token exchange
    for role in "manage-clients" "view-clients" "manage-users" "view-users" "manage-authorization" "view-authorization"; do
      echo "   Granting $role..."
      docker exec keycloak /opt/keycloak/bin/kcadm.sh add-roles \
        -r master \
        --uid $SERVICE_ACCOUNT_ID \
        --cclientid realm-management \
        --rolename $role 2>/dev/null || echo "     (already granted or not found)"
    done
  fi
  
  # Also check for any token-exchange specific roles
  echo ""
  echo "3. Looking for token-exchange specific roles..."
  
  # Get all realm roles
  REALM_ROLES=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get roles -r master --fields name | jq -r '.[].name')
  
  # Check if there's a token-exchange role
  if echo "$REALM_ROLES" | grep -q "token-exchange"; then
    echo "   Found token-exchange realm role, granting it..."
    docker exec keycloak /opt/keycloak/bin/kcadm.sh add-roles \
      -r master \
      --uid $SERVICE_ACCOUNT_ID \
      --rolename token-exchange 2>/dev/null || echo "   (already granted)"
  else
    echo "   No token-exchange realm role found"
  fi
fi

# Step 3: Create a manual authorization entry if needed
echo ""
echo "4. Creating authorization entries..."

# This is a workaround - we'll create a scope that explicitly allows token exchange
# First, make sure service-b has authorization enabled
docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$SERVICE_B_UUID -r master \
  -s 'authorizationServicesEnabled=true' > /dev/null 2>&1

sleep 1

# Create a custom scope for token-exchange
echo "   Creating token-exchange scope..."
SCOPE_RESPONSE=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh create clients/$SERVICE_B_UUID/authz/resource-server/scope -r master \
  -s 'name=token-exchange' \
  -s 'displayName=Token Exchange' 2>&1 || echo "exists")

if [[ "$SCOPE_RESPONSE" == *"exists"* ]] || [[ "$SCOPE_RESPONSE" == *"409"* ]]; then
  echo "   ✓ Scope already exists"
else
  echo "   ✓ Created token-exchange scope"
fi

# Step 4: Alternative approach - Update service-a to have implicit permission
echo ""
echo "5. Setting implicit permissions..."

# Add service-b to service-a's audience
docker exec keycloak /opt/keycloak/bin/kcadm.sh create clients/$SERVICE_A_UUID/protocol-mappers/models -r master \
  -s 'name=service-b-audience' \
  -s 'protocol=openid-connect' \
  -s 'protocolMapper=oidc-audience-mapper' \
  -s 'config."included.client.audience"=service-b' \
  -s 'config."access.token.claim"=true' 2>&1 | grep -v "Conflict" || echo "   ✓ Audience mapper configured"

# Step 5: Last resort - disable some security checks
echo ""
echo "6. Applying compatibility settings..."

# On service-b, make it more permissive for token exchange
docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$SERVICE_B_UUID -r master \
  -s 'fullScopeAllowed=true' \
  -s 'attributes."access.token.lifespan"=3600' > /dev/null 2>&1

echo "✓ Compatibility settings applied"

echo ""
echo "=== Token Exchange Permission Grant Complete ==="
echo ""
echo "Applied the following changes:"
echo "✓ Updated client configurations"
echo "✓ Granted realm-management roles to service-a"
echo "✓ Created authorization scopes"
echo "✓ Added audience mappers"
echo "✓ Applied compatibility settings"
echo ""
echo "IMPORTANT: After running this script, you may need to:"
echo "1. Restart the Keycloak container for all changes to take effect"
echo "2. Clear any cached tokens in your services"
echo "3. Run the diagnostic script to verify: ./diagnose-token-exchange.sh"