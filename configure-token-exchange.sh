#!/bin/bash
set -e

echo "Configuring token exchange for service-a client..."

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

# Get service-a client UUID
CLIENT_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="service-a") | .id')

if [ -z "$CLIENT_UUID" ]; then
  echo "✗ Could not find service-a client"
  exit 1
fi

# Enable token exchange on the client by setting the specific attribute
echo "Enabling standard token exchange for service-a..."
docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$CLIENT_UUID -r master \
  -s 'attributes."access.token.signed.response.alg"=RS256' \
  -s 'attributes."token-exchange-permissions-enabled"=true' \
  -s 'attributes."token.exchange.grant.enabled"=true' \
  -s 'publicClient=false' \
  -s 'serviceAccountsEnabled=true' \
  -s 'directAccessGrantsEnabled=true' \
  -s 'standardFlowEnabled=true'

echo "✓ Token exchange enabled for service-a"

# Also ensure service-b (banking-service) can be a target for token exchange
BANKING_CLIENT_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="service-b") | .id')

if [ -n "$BANKING_CLIENT_UUID" ]; then
  echo "Configuring service-b as token exchange target..."
  docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$BANKING_CLIENT_UUID -r master \
    -s 'attributes."token-exchange-permissions-enabled"=true' \
    -s 'publicClient=false'
  echo "✓ service-b configured as token exchange target"
fi

echo "✓ Token exchange configuration complete"