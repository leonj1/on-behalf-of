#!/bin/bash
set -e

echo "=== Checking Keycloak Features and Configuration ==="
echo ""

# Check if Keycloak container is running
if ! docker ps | grep -q keycloak; then
  echo "✗ Keycloak container is not running"
  exit 1
fi

# Check Keycloak version and build info
echo "1. Keycloak Version and Build Info:"
docker exec keycloak /opt/keycloak/bin/kc.sh show-config | grep -E "(version|features|token)" || echo "Could not get config"
echo ""

# Check the actual command line Keycloak is running with
echo "2. Keycloak Process Command Line:"
docker exec keycloak ps aux | grep -v grep | grep java | sed 's/.*java/java/' | tr ' ' '\n' | grep -E "(feature|token|exchange)" || echo "No feature flags found in process"
echo ""

# Check if token-exchange is listed in features
echo "3. Checking enabled features:"
docker exec keycloak /opt/keycloak/bin/kc.sh show-config | grep -A 20 "Current Features" || echo "Features section not found"
echo ""

# Check container logs for feature warnings
echo "4. Recent Keycloak logs mentioning token exchange:"
docker logs keycloak 2>&1 | tail -100 | grep -i "token.exchange\|feature" | tail -10 || echo "No relevant logs found"
echo ""

# Try to check feature status via API
echo "5. Checking feature status via Admin API:"
# Get admin token
TOKEN_RESPONSE=$(curl -s -X POST http://localhost:8080/realms/master/protocol/openid-connect/token \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin")

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token // empty')

if [ -n "$ACCESS_TOKEN" ]; then
  # Try to get server info
  SERVER_INFO=$(curl -s -X GET "http://localhost:8080/admin/serverinfo" \
    -H "Authorization: Bearer $ACCESS_TOKEN")
  
  echo "Token Exchange Feature Status:"
  echo $SERVER_INFO | jq '.profileInfo.features // .features // empty' | grep -i token || echo "No token exchange feature info found"
fi

echo ""
echo "=== Diagnosis ==="
echo ""
echo "If token-exchange feature is not shown as enabled above, then:"
echo "1. Keycloak needs to be restarted with the feature flag"
echo "2. The docker-compose.yml change may not have taken effect"
echo "3. Your Keycloak version may not support token exchange"
echo ""
echo "To fix:"
echo "1. Stop all services: make stop"
echo "2. Start fresh: docker-compose down -v"
echo "3. Restart: make setup"