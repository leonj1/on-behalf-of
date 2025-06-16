#!/bin/bash
set -e

echo "Updating frontend client secret..."

# Check if Keycloak container is running
if ! docker ps | grep -q keycloak; then
  echo "✗ Keycloak container is not running"
  echo "  Please ensure 'make start' has been run first"
  exit 1
fi

# Authenticate with Keycloak
if ! docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin \
  --client admin-cli > /dev/null 2>&1; then
  echo "✗ Failed to authenticate with Keycloak"
  echo "  Keycloak may still be starting up"
  exit 1
fi

# Get client UUID and secret
CLIENT_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="nextjs-app") | .id')

if [ -n "$CLIENT_UUID" ]; then
  SECRET=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$CLIENT_UUID/client-secret -r master | jq -r '.value')
  
  if [ -n "$SECRET" ]; then
    # Update the .env.local file
    if [ -f "frontend/.env.local" ]; then
      # Use sed to update the KEYCLOAK_CLIENT_SECRET line
      sed -i.bak "s/^KEYCLOAK_CLIENT_SECRET=.*/KEYCLOAK_CLIENT_SECRET=$SECRET/" frontend/.env.local
      rm -f frontend/.env.local.bak
      echo "✓ Updated frontend/.env.local with new client secret"
      
      # Restart frontend to apply changes (only if it's running)
      if docker ps --format "table {{.Names}}" | grep -q "^frontend$"; then
        docker-compose restart frontend > /dev/null 2>&1
        echo "✓ Restarted frontend service"
      else
        echo "✓ Frontend not running yet - changes will apply when started"
      fi
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