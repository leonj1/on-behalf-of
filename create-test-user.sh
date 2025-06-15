#!/bin/bash
set -e

echo "Creating test user in Keycloak..."

# Authenticate with Keycloak
docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin \
  --client admin-cli > /dev/null 2>&1

# Create test user
docker exec keycloak /opt/keycloak/bin/kcadm.sh create users -r master \
  -s username=testuser \
  -s email=testuser@example.com \
  -s emailVerified=true \
  -s enabled=true

# Get user ID
USER_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get users -r master -q username=testuser | jq -r '.[0].id')

if [ -n "$USER_ID" ]; then
  # Set password
  docker exec keycloak /opt/keycloak/bin/kcadm.sh set-password -r master \
    --username testuser \
    --new-password testpass123
  
  echo "✓ Test user created successfully"
  echo ""
  echo "Test User Credentials:"
  echo "  Username: testuser"
  echo "  Password: testpass123"
  echo "  Email: testuser@example.com"
else
  echo "✗ Failed to create test user"
  exit 1
fi