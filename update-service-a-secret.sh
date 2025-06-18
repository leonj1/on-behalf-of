#!/bin/bash
set -e

echo "Updating service-a client secret..."

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
CLIENT_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="service-a") | .id')

if [ -n "$CLIENT_UUID" ]; then
  SECRET=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$CLIENT_UUID/client-secret -r master | jq -r '.value')
  
  if [ -n "$SECRET" ]; then
    # Update the .env file with the new secret
    if [ -f ".env" ]; then
      # Check if SERVICE_A_CLIENT_SECRET exists in .env
      if grep -q "^SERVICE_A_CLIENT_SECRET=" .env; then
        # Update existing value
        sed -i.bak "s/^SERVICE_A_CLIENT_SECRET=.*/SERVICE_A_CLIENT_SECRET=$SECRET/" .env
      else
        # Add new value
        echo "SERVICE_A_CLIENT_SECRET=$SECRET" >> .env
      fi
      rm -f .env.bak
      echo "✓ Updated .env with new service-a client secret"
      
      # Export the variable for docker-compose
      export SERVICE_A_CLIENT_SECRET=$SECRET
      
      # Restart service-a to apply changes (only if it's running)
      if docker ps --format "table {{.Names}}" | grep -q "^service-a$"; then
        docker-compose restart service-a > /dev/null 2>&1
        echo "✓ Restarted service-a with new client secret"
      else
        echo "✓ Service-a not running yet - changes will apply when started"
      fi
    else
      # If no .env file, create one with the secret
      echo "SERVICE_A_CLIENT_SECRET=$SECRET" > .env
      echo "✓ Created .env with service-a client secret"
    fi
  else
    echo "✗ Could not retrieve client secret"
    exit 1
  fi
else
  echo "✗ Could not find service-a client"
  exit 1
fi