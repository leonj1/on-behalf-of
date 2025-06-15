#!/bin/bash
set -e

echo "Updating frontend client secret..."

# Authenticate with Keycloak
docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin \
  --client admin-cli > /dev/null 2>&1

# Get client UUID and secret
CLIENT_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="nextjs-app") | .id')

if [ -n "$CLIENT_UUID" ]; then
  SECRET=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$CLIENT_UUID/client-secret -r master | jq -r '.value')
  
  if [ -n "$SECRET" ]; then
    # Update the .env.local file
    if [ -f "frontend/.env.local" ]; then
      # Use sed to update the KEYCLOAK_CLIENT_SECRET line
      sed -i "s/^KEYCLOAK_CLIENT_SECRET=.*/KEYCLOAK_CLIENT_SECRET=$SECRET/" frontend/.env.local
      echo "✓ Updated frontend/.env.local with new client secret"
      
      # Restart frontend to apply changes
      docker compose restart frontend > /dev/null 2>&1
      echo "✓ Restarted frontend service"
    else
      echo "✗ frontend/.env.local not found"
      exit 1
    fi
  else
    echo "✗ Could not retrieve client secret"
    exit 1
  fi
else
  echo "✗ Could not find nextjs-app client"
  exit 1
fi