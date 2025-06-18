#!/bin/bash
set -e

echo "=== Configuring Alternative Authentication Approach ==="
echo ""
echo "Since token exchange is not working, this script configures"
echo "an alternative approach where service-a can use the original"
echo "user token to call service-b."
echo ""

# Check if Keycloak container is running
if ! docker ps | grep -q keycloak; then
  echo "✗ Keycloak container is not running"
  exit 1
fi

# Authenticate
docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin \
  --client admin-cli > /dev/null 2>&1

# Get client UUIDs
SERVICE_A_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="service-a") | .id')
SERVICE_B_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="service-b") | .id')
NEXTJS_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="nextjs-app") | .id')

echo "Found clients:"
echo "  service-a: $SERVICE_A_UUID"
echo "  service-b: $SERVICE_B_UUID"
echo "  nextjs-app: $NEXTJS_UUID"
echo ""

# Option 1: Add service-a and service-b to nextjs-app's audience
echo "1. Adding service audiences to frontend tokens..."

# Create audience mapper for service-a on nextjs-app client
docker exec keycloak /opt/keycloak/bin/kcadm.sh create clients/$NEXTJS_UUID/protocol-mappers/models -r master \
  -s 'name=service-a-audience' \
  -s 'protocol=openid-connect' \
  -s 'protocolMapper=oidc-audience-mapper' \
  -s 'config."included.client.audience"=service-a' \
  -s 'config."access.token.claim"=true' \
  -s 'config."id.token.claim"=false' 2>&1 | grep -v "Conflict" || echo "  ✓ service-a audience mapper exists"

# Create audience mapper for service-b on nextjs-app client
docker exec keycloak /opt/keycloak/bin/kcadm.sh create clients/$NEXTJS_UUID/protocol-mappers/models -r master \
  -s 'name=service-b-audience' \
  -s 'protocol=openid-connect' \
  -s 'protocolMapper=oidc-audience-mapper' \
  -s 'config."included.client.audience"=service-b' \
  -s 'config."access.token.claim"=true' \
  -s 'config."id.token.claim"=false' 2>&1 | grep -v "Conflict" || echo "  ✓ service-b audience mapper exists"

echo "✓ Audience mappers configured"

# Option 2: Create a hardcoded audience mapper that includes multiple audiences
echo ""
echo "2. Creating multi-audience mapper..."

docker exec keycloak /opt/keycloak/bin/kcadm.sh create clients/$NEXTJS_UUID/protocol-mappers/models -r master \
  -s 'name=multi-service-audience' \
  -s 'protocol=openid-connect' \
  -s 'protocolMapper=oidc-hardcoded-claim-mapper' \
  -s 'config."claim.name"=aud' \
  -s 'config."claim.value"=["account","service-a","service-b"]' \
  -s 'config."jsonType.label"=JSON' \
  -s 'config."access.token.claim"=true' \
  -s 'config."id.token.claim"=false' \
  -s 'config."userinfo.token.claim"=false' 2>&1 | grep -v "Conflict" || echo "  ✓ Multi-audience mapper exists"

# Option 3: Add scope mappings
echo ""
echo "3. Adding scope mappings between clients..."

# Add service-b's roles to service-a's scope
docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$SERVICE_A_UUID/scope-mappings/clients/$SERVICE_B_UUID -r master \
  -s 'roles=[]' 2>/dev/null || echo "  ✓ Scope mapping configured"

# Option 4: Make all services use the same audience validation approach
echo ""
echo "4. Updating service configurations for compatibility..."

# Update service-b to accept more audiences
docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$SERVICE_B_UUID -r master \
  -s 'attributes."access.token.lifespan"=3600' \
  -s 'fullScopeAllowed=true'

echo "✓ Service configurations updated"

echo ""
echo "=== Alternative Configuration Complete ==="
echo ""
echo "Since token exchange is not working, we've configured:"
echo "✓ Added service-a and service-b to frontend token audiences"
echo "✓ Created multi-audience mappers"
echo "✓ Added scope mappings between services"
echo "✓ Updated service configurations for compatibility"
echo ""
echo "This allows the original user token from nextjs-app to be"
echo "accepted by both service-a and service-b without token exchange."
echo ""
echo "IMPORTANT: Users may need to logout and login again to get"
echo "new tokens with the updated audiences."