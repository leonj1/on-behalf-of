#!/bin/bash
set -e

echo "Updating service-b client secret..."

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
CLIENT_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="service-b") | .id')

if [ -n "$CLIENT_UUID" ]; then
  SECRET=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$CLIENT_UUID/client-secret -r master | jq -r '.value')
  
  if [ -n "$SECRET" ]; then
    # Update the .env file with the new secret
    if [ -f ".env" ]; then
      # Check if SERVICE_B_CLIENT_SECRET exists in .env
      if grep -q "^SERVICE_B_CLIENT_SECRET=" .env; then
        # Update existing value
        sed -i.bak "s/^SERVICE_B_CLIENT_SECRET=.*/SERVICE_B_CLIENT_SECRET=$SECRET/" .env
      else
        # Add new value
        echo "SERVICE_B_CLIENT_SECRET=$SECRET" >> .env
      fi
      rm -f .env.bak
      echo "✓ Updated .env with new service-b client secret"
      
      # Export the variable for docker-compose
      export SERVICE_B_CLIENT_SECRET=$SECRET
      
      # Note: service-b (banking-service) doesn't currently use client credentials
      # but this script is here for completeness and future use
      echo "✓ Service-b client secret updated (currently not used by banking-service)"
    else
      # If no .env file, create one with the secret
      echo "SERVICE_B_CLIENT_SECRET=$SECRET" > .env
      echo "✓ Created .env with service-b client secret"
    fi
  else
    echo "✗ Could not retrieve client secret"
    exit 1
  fi
else
  echo "✗ Could not find service-b client"
  exit 1
fi