#!/bin/bash
set -e

echo "Updating nextjs-app client redirect URIs..."

# Authenticate with Keycloak
docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin \
  --client admin-cli > /dev/null 2>&1

# Get client UUID
CLIENT_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="nextjs-app") | .id')

if [ -n "$CLIENT_UUID" ]; then
  # Load configuration
  if [ -f .env ]; then
    source .env
    FRONTEND_URL="${FRONTEND_EXTERNAL_URL:-http://localhost:3005}"
  else
    FRONTEND_URL="http://localhost:3005"
  fi
  
  # Update redirect URIs to include configured frontend URL
  docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$CLIENT_UUID -r master \
    -s "redirectUris=[\"${FRONTEND_URL}/*\",\"http://localhost:3005/*\",\"http://localhost:3000/*\"]" \
    -s "webOrigins=[\"${FRONTEND_URL}\",\"http://localhost:3005\",\"http://localhost:3000\"]"
  
  echo "✓ Updated nextjs-app client redirect URIs"
else
  echo "✗ Could not find nextjs-app client"
  exit 1
fi