#!/bin/bash
# Standalone script to disable Keycloak SSL requirements
# Can be run manually if automatic configuration fails

set -e

echo "=== Disabling Keycloak SSL Requirements ==="
echo

# Check if Keycloak is running
if ! docker ps | grep -q keycloak; then
  echo "Error: Keycloak container is not running"
  echo "Please run 'make start' first"
  exit 1
fi

# Wait for Keycloak to be accessible
echo "Checking Keycloak availability..."
if ! curl -sf http://localhost:8080/ > /dev/null 2>&1; then
  echo "Error: Keycloak is not accessible at http://localhost:8080"
  echo "Please ensure Keycloak is running and ready"
  exit 1
fi

echo "✓ Keycloak is accessible"
echo

# Run the configuration
./configure-keycloak.sh

echo
echo "=== Testing HTTP access from external IP ==="
echo

# Test access from the server IP
if curl -sf http://100.68.45.127:8080/ > /dev/null 2>&1; then
  echo "✓ Successfully accessed Keycloak via HTTP from 100.68.45.127"
  echo "✓ You can now access Keycloak admin console at: http://100.68.45.127:8080"
  echo "✓ Username: admin"
  echo "✓ Password: admin"
else
  echo "✗ Failed to access Keycloak from external IP"
  echo "Please check the logs with: docker logs keycloak"
fi