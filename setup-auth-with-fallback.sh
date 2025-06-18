#!/bin/bash
set -e

echo "=== Setting up Authentication with Fallback ==="
echo ""
echo "This script attempts to set up token exchange, and if that fails,"
echo "configures an alternative authentication approach."
echo ""

# First, check if token exchange feature is actually enabled
echo "1. Checking if token exchange feature is enabled in Keycloak..."
./check-keycloak-features.sh || true
echo ""

# Try to set up token exchange
echo "2. Attempting to configure token exchange..."
echo "----------------------------------------"

# Run all the token exchange setup scripts
./enable-realm-token-exchange.sh || echo "  ⚠️  Realm token exchange setup had issues"
echo ""
./configure-keycloak-token-exchange.sh || echo "  ⚠️  Client token exchange setup had issues"
echo ""
./fix-token-exchange.sh || echo "  ⚠️  Token exchange fixes had issues"
echo ""
./enable-token-exchange-permissions.sh || echo "  ⚠️  Permission setup had issues"
echo ""
./create-token-exchange-policy.sh || echo "  ⚠️  Policy creation had issues"
echo ""
./grant-token-exchange.sh || echo "  ⚠️  Permission grant had issues"
echo ""

# Test if token exchange works
echo "3. Testing token exchange..."
echo "----------------------------------------"

# Get service-a secret for testing
SERVICE_A_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId 2>/dev/null | jq -r '.[] | select(.clientId=="service-a") | .id')
if [ -n "$SERVICE_A_UUID" ]; then
  SECRET=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_A_UUID/client-secret -r master 2>/dev/null | jq -r '.value')
  export SERVICE_A_CLIENT_SECRET=$SECRET
  export KEYCLOAK_URL=http://localhost:8080
  
  if python3 test-token-exchange.py; then
    echo ""
    echo "✅ Token exchange is working!"
    echo "   The on-behalf-of flow will use token exchange."
  else
    echo ""
    echo "⚠️  Token exchange is not working."
    echo "   Setting up alternative authentication approach..."
    echo ""
    
    # Configure alternative approach
    echo "4. Configuring alternative authentication..."
    echo "----------------------------------------"
    ./configure-alternative-auth.sh
    
    echo ""
    echo "✅ Alternative authentication configured!"
    echo "   The system will use the original user token with multiple audiences."
    echo ""
    echo "   IMPORTANT: Users need to logout and login again to get new tokens."
  fi
fi

echo ""
echo "=== Authentication Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Run: SKIP_TOKEN_EXCHANGE_CHECK=true make setup-clients"
echo "2. Complete the rest of the setup: make setup-consent-store"
echo "3. Test the application"