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
  # Update redirect URIs to include port 3005 and external IP
  docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$CLIENT_UUID -r master \
    -s 'redirectUris=["http://localhost:3005/*","http://localhost:3000/*","http://10.1.1.74:3005/*"]' \
    -s 'webOrigins=["http://localhost:3005","http://localhost:3000","http://10.1.1.74:3005"]'
  
  echo "✓ Updated nextjs-app client redirect URIs"
else
  echo "✗ Could not find nextjs-app client"
  exit 1
fi