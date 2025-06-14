#!/bin/bash
set -e

echo "Starting integration test..."

# Stop any existing Keycloak instance
echo "Stopping any existing Keycloak instance..."
make stop || true

# Start Keycloak fresh
echo "Starting Keycloak..."
make start

# Wait a bit more to ensure Keycloak is fully ready
echo "Waiting for Keycloak to be fully initialized..."
sleep 5

# Create client IDs
echo "Creating client IDs..."
python3 create-clientid.py --client-id service-a
python3 create-clientid.py --client-id service-b

# Verify clients were created
echo "Verifying clients..."
TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "Failed to get admin token"
  exit 1
fi

# Check if service-a exists
SERVICE_A=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8080/admin/realms/master/clients?clientId=service-a" | grep -o '"clientId":"service-a"')

if [ -z "$SERVICE_A" ]; then
  echo "service-a client not found"
  exit 1
fi

# Check if service-b exists
SERVICE_B=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8080/admin/realms/master/clients?clientId=service-b" | grep -o '"clientId":"service-b"')

if [ -z "$SERVICE_B" ]; then
  echo "service-b client not found"
  exit 1
fi

echo "Integration test completed successfully!"
echo "Keycloak is running with service-a and service-b clients configured."