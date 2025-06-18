#!/bin/bash
set -e

echo "Enabling token exchange at realm level..."

# Check if Keycloak container is running
if ! docker ps | grep -q keycloak; then
  echo "✗ Keycloak container is not running"
  exit 1
fi

# Authenticate with Keycloak
docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin \
  --client admin-cli > /dev/null 2>&1

# Method 1: Try to enable token exchange feature at realm level
echo "Attempting to enable token exchange feature..."
docker exec keycloak /opt/keycloak/bin/kcadm.sh update realms/master -r master \
  -s 'attributes."tokenExchange"=true' 2>/dev/null || echo "  Feature flag may not exist in this version"

# Method 2: Update realm to ensure proper token settings
echo "Configuring realm token settings..."
docker exec keycloak /opt/keycloak/bin/kcadm.sh update realms/master -r master \
  -s 'accessTokenLifespan=1800' \
  -s 'accessTokenLifespanForImplicitFlow=1800' \
  -s 'ssoSessionIdleTimeout=1800' \
  -s 'ssoSessionMaxLifespan=36000' \
  -s 'offlineSessionIdleTimeout=2592000' \
  -s 'offlineSessionMaxLifespanEnabled=false'

# Method 3: Create realm-level admin role mappings for service accounts
echo "Setting up realm admin permissions..."

# Get service-a's service account user
SERVICE_A_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="service-a") | .id')
if [ -n "$SERVICE_A_UUID" ]; then
  SERVICE_ACCOUNT_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_A_UUID/service-account-user -r master 2>/dev/null | jq -r '.id' || echo "")
  
  if [ -n "$SERVICE_ACCOUNT_ID" ]; then
    echo "Adding token-exchange role to service-a service account..."
    
    # Try to add the token-exchange role if it exists
    docker exec keycloak /opt/keycloak/bin/kcadm.sh add-roles \
      -r master \
      --uid $SERVICE_ACCOUNT_ID \
      --rolename "token-exchange" 2>/dev/null || echo "  Token-exchange role may not exist"
    
    # Add view-clients role to allow seeing other clients
    docker exec keycloak /opt/keycloak/bin/kcadm.sh add-roles \
      -r master \
      --uid $SERVICE_ACCOUNT_ID \
      --cclientid realm-management \
      --rolename view-clients 2>/dev/null || echo "  Role may already be assigned"
  fi
fi

echo "✓ Realm-level token exchange configuration complete"