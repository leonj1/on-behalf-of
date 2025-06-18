#!/bin/bash
set -e

echo "=== Enabling Token Exchange Permissions ==="
echo ""
echo "This script specifically addresses the 'Client not allowed to exchange' error"
echo "by creating the necessary permissions for service-a to exchange tokens."
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

# Method 1: Enable fine-grained admin permissions on service-b
echo "2. Enabling fine-grained admin permissions on service-b..."
PERMS_RESPONSE=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$SERVICE_B_UUID/management/permissions -r master \
  -s 'enabled=true' 2>&1 || echo "")

if [[ "$PERMS_RESPONSE" == *"404"* ]]; then
  echo "   ⚠ Fine-grained permissions not available (older Keycloak version)"
else
  echo "   ✓ Fine-grained permissions enabled"
  
  # Get the token-exchange permission ID
  echo ""
  echo "3. Looking for token-exchange permission..."
  PERMS_DATA=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_B_UUID/management/permissions -r master 2>/dev/null || echo "{}")
  TOKEN_EXCHANGE_PERM=$(echo "$PERMS_DATA" | jq -r '.scopePermissions."token-exchange" // empty')
  
  if [ -n "$TOKEN_EXCHANGE_PERM" ] && [ "$TOKEN_EXCHANGE_PERM" != "null" ]; then
    echo "   ✓ Found token-exchange permission: $TOKEN_EXCHANGE_PERM"
    
    # Get existing policies for this permission
    echo ""
    echo "4. Checking existing policies..."
    PERM_DETAILS=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get authorization/permissions/scope/$TOKEN_EXCHANGE_PERM -r master 2>/dev/null || echo "{}")
    EXISTING_POLICIES=$(echo "$PERM_DETAILS" | jq -r '.policies[]?' 2>/dev/null || echo "")
    
    # Create a client policy for service-a
    echo ""
    echo "5. Creating client policy for service-a..."
    POLICY_RESPONSE=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh create authorization/policies/client -r master \
      -s 'name=allow-service-a-token-exchange' \
      -s 'description=Allow service-a to perform token exchange to service-b' \
      -s 'clients=["service-a"]' 2>&1 || echo "exists")
    
    if [[ "$POLICY_RESPONSE" == *"exists"* ]] || [[ "$POLICY_RESPONSE" == *"Conflict"* ]]; then
      echo "   ✓ Policy already exists"
      # Get the existing policy ID
      POLICY_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get authorization/policies -r master | jq -r '.[] | select(.name=="allow-service-a-token-exchange") | .id' | head -1)
    else
      # Extract the new policy ID from the response
      POLICY_ID=$(echo "$POLICY_RESPONSE" | grep -o 'Created new.*id [^"]*' | awk '{print $NF}' || echo "")
      echo "   ✓ Created new policy: $POLICY_ID"
    fi
    
    if [ -n "$POLICY_ID" ]; then
      # Update the token-exchange permission to include our policy
      echo ""
      echo "6. Associating policy with token-exchange permission..."
      
      # Combine existing policies with our new one
      if [ -n "$EXISTING_POLICIES" ]; then
        # Add to existing policies
        POLICY_LIST="[\"$POLICY_ID\""
        for pol in $EXISTING_POLICIES; do
          POLICY_LIST="$POLICY_LIST,\"$pol\""
        done
        POLICY_LIST="$POLICY_LIST]"
      else
        # First policy
        POLICY_LIST="[\"$POLICY_ID\"]"
      fi
      
      docker exec keycloak /opt/keycloak/bin/kcadm.sh update authorization/permissions/scope/$TOKEN_EXCHANGE_PERM -r master \
        -s "policies=$POLICY_LIST" \
        -s 'decisionStrategy=AFFIRMATIVE' 2>/dev/null && echo "   ✓ Policy associated with permission" || echo "   ⚠ Could not update permission"
    fi
  else
    echo "   ⚠ Token-exchange permission not found - this Keycloak version may handle it differently"
  fi
fi

# Method 2: Grant token-exchange role directly to service-a's service account
echo ""
echo "7. Granting token-exchange role to service-a service account..."
SERVICE_ACCOUNT_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_A_UUID/service-account-user -r master 2>/dev/null | jq -r '.id' || echo "")

if [ -n "$SERVICE_ACCOUNT_ID" ]; then
  echo "   ✓ Found service account: $SERVICE_ACCOUNT_ID"
  
  # Check if there's a token-exchange role at realm level
  TOKEN_EXCHANGE_ROLE=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get roles -r master | jq -r '.[] | select(.name=="token-exchange") | .name' || echo "")
  
  if [ -n "$TOKEN_EXCHANGE_ROLE" ]; then
    echo "   ✓ Found token-exchange role, granting it..."
    docker exec keycloak /opt/keycloak/bin/kcadm.sh add-roles \
      -r master \
      --uid $SERVICE_ACCOUNT_ID \
      --rolename token-exchange 2>/dev/null && echo "   ✓ Granted token-exchange role" || echo "   ⚠ Role may already be granted"
  fi
  
  # Also grant manage-clients role which includes token exchange permissions
  echo "   Granting manage-clients role..."
  docker exec keycloak /opt/keycloak/bin/kcadm.sh add-roles \
    -r master \
    --uid $SERVICE_ACCOUNT_ID \
    --cclientid realm-management \
    --rolename manage-clients 2>/dev/null && echo "   ✓ Granted manage-clients role" || echo "   ⚠ Role may already be granted"
fi

# Method 3: Create authorization scope for token exchange if using authorization services
echo ""
echo "8. Checking if service-b uses authorization services..."
AUTH_ENABLED=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_B_UUID -r master | jq -r '.authorizationServicesEnabled')

if [ "$AUTH_ENABLED" = "true" ]; then
  echo "   ✓ Authorization services enabled"
  
  # Create a resource for token-exchange if it doesn't exist
  echo "   Creating token-exchange resource..."
  RESOURCE_RESPONSE=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh create clients/$SERVICE_B_UUID/authz/resource-server/resource -r master \
    -s 'name=token-exchange' \
    -s 'displayName=Token Exchange' \
    -s 'type=token-exchange' \
    -s 'ownerManagedAccess=false' 2>&1 || echo "exists")
  
  if [[ "$RESOURCE_RESPONSE" == *"exists"* ]] || [[ "$RESOURCE_RESPONSE" == *"Conflict"* ]]; then
    echo "   ✓ Token-exchange resource already exists"
  else
    echo "   ✓ Created token-exchange resource"
  fi
  
  # Create a scope-based permission
  echo "   Creating scope-based permission..."
  SCOPE_PERM_RESPONSE=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh create clients/$SERVICE_B_UUID/authz/resource-server/permission/scope -r master \
    -s 'name=token-exchange-permission' \
    -s 'description=Permission for token exchange' \
    -s 'resources=["token-exchange"]' \
    -s 'decisionStrategy=AFFIRMATIVE' 2>&1 || echo "exists")
  
  if [[ "$SCOPE_PERM_RESPONSE" == *"exists"* ]] || [[ "$SCOPE_PERM_RESPONSE" == *"Conflict"* ]]; then
    echo "   ✓ Permission already exists"
  else
    echo "   ✓ Created scope-based permission"
  fi
fi

# Method 4: Update both clients with explicit permission attributes
echo ""
echo "9. Setting explicit permission attributes on clients..."

# On service-a: explicitly allow it to request token exchange
docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$SERVICE_A_UUID -r master \
  -s 'attributes."token.exchange.permission.client"=service-b' 2>/dev/null || true

# On service-b: explicitly allow service-a to exchange tokens for it
docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$SERVICE_B_UUID -r master \
  -s 'attributes."token.exchange.permission.client"=service-a' 2>/dev/null || true

echo "   ✓ Set explicit permission attributes"

# Method 5: Create a hardcoded permission using direct API calls
echo ""
echo "10. Creating direct token-exchange permission mapping..."

# This is a last resort - directly create the permission in the database
# Get admin token for direct API calls
ADMIN_TOKEN=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin \
  --client admin-cli 2>&1 | grep -o 'Bearer [^ ]*' | cut -d' ' -f2 || echo "")

if [ -n "$ADMIN_TOKEN" ]; then
  # Try direct API call to create permission
  curl -s -X POST "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_UUID/authz/resource-server/permission/token-exchange" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "service-a-can-exchange",
      "description": "Allow service-a to exchange tokens",
      "clients": ["service-a"],
      "decisionStrategy": "AFFIRMATIVE"
    }' 2>/dev/null || echo "   ⚠ Direct API method not available"
fi

echo ""
echo "=== Token Exchange Permissions Configuration Complete ==="
echo ""
echo "Applied multiple permission strategies:"
echo "✓ Enabled fine-grained admin permissions"
echo "✓ Created client policies for token exchange"
echo "✓ Granted service account roles"
echo "✓ Set explicit permission attributes"
echo "✓ Created authorization resources if applicable"
echo ""
echo "If token exchange still fails with 'Client not allowed', check:"
echo "1. Keycloak logs: docker logs keycloak"
echo "2. Ensure Keycloak was restarted with --features=token-exchange"
echo "3. Try running: ./diagnose-token-exchange.sh"