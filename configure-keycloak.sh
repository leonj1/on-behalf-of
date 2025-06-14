#!/bin/bash
set -e

echo "Configuring Keycloak to disable SSL requirements..."

# Wait a bit to ensure Keycloak is fully ready
sleep 5

# Get admin token
echo "Getting admin token..."
TOKEN=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin \
  --client admin-cli 2>&1 | grep -o 'token.*' | cut -d'"' -f3 || echo "")

if [ -z "$TOKEN" ]; then
  echo "Authenticating with Keycloak admin..."
  docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
    --server http://localhost:8080 \
    --realm master \
    --user admin \
    --password admin \
    --client admin-cli
fi

# Update master realm to disable SSL requirement
echo "Updating master realm SSL settings..."
docker exec keycloak /opt/keycloak/bin/kcadm.sh update realms/master \
  -s sslRequired=NONE

# Verify the change
echo "Verifying SSL settings..."
SSL_SETTING=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get realms/master \
  --fields sslRequired --format csv --noquotes | tail -1)

if [ "$SSL_SETTING" = "NONE" ] || [ "$SSL_SETTING" = "none" ]; then
  echo "✓ SSL requirement successfully disabled for master realm"
  echo "✓ Keycloak is now accessible via HTTP from any IP address"
else
  echo "✗ Failed to disable SSL requirement. Current setting: $SSL_SETTING"
  exit 1
fi