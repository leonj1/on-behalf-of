#!/bin/bash
set -e

# Check if client ID and secret are provided
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <GOOGLE_CLIENT_ID> <GOOGLE_CLIENT_SECRET>"
  echo ""
  echo "Please provide your Google OAuth2 credentials as arguments."
  echo "See GOOGLE_AUTH_SETUP.md for instructions on obtaining these credentials."
  exit 1
fi

GOOGLE_CLIENT_ID="$1"
GOOGLE_CLIENT_SECRET="$2"

echo "Configuring Google authentication in Keycloak..."

# Wait a bit to ensure Keycloak is fully ready
sleep 5

# Authenticate with Keycloak
echo "Authenticating with Keycloak admin..."
docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin \
  --client admin-cli > /dev/null 2>&1

# Check if Google identity provider already exists
echo "Checking for existing Google identity provider..."
EXISTING_PROVIDER=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get identity-provider/instances -r master | jq -r '.[] | select(.alias == "google") | .alias' || echo "")

if [ -n "$EXISTING_PROVIDER" ]; then
  echo "Google identity provider already exists. Updating configuration..."
  # Update existing provider
  docker exec keycloak /opt/keycloak/bin/kcadm.sh update identity-provider/instances/google -r master \
    -s config.clientId="$GOOGLE_CLIENT_ID" \
    -s config.clientSecret="$GOOGLE_CLIENT_SECRET" \
    -s config.defaultScope="openid profile email" \
    -s config.useJwksUrl=true \
    -s enabled=true \
    -s trustEmail=true \
    -s storeToken=true \
    -s addReadTokenRoleOnCreate=true \
    -s firstBrokerLoginFlowAlias="first broker login"
else
  echo "Creating Google identity provider..."
  # Create new Google identity provider
  docker exec keycloak /opt/keycloak/bin/kcadm.sh create identity-provider/instances -r master \
    -s alias=google \
    -s providerId=google \
    -s displayName="Google" \
    -s enabled=true \
    -s trustEmail=true \
    -s storeToken=true \
    -s addReadTokenRoleOnCreate=true \
    -s firstBrokerLoginFlowAlias="first broker login" \
    -s config.clientId="$GOOGLE_CLIENT_ID" \
    -s config.clientSecret="$GOOGLE_CLIENT_SECRET" \
    -s config.defaultScope="openid profile email" \
    -s config.useJwksUrl=true
fi

# Add identity provider redirector to authentication flow
echo "Configuring authentication flow..."

# Get the browser flow ID
BROWSER_FLOW_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get authentication/flows -r master | jq -r '.[] | select(.alias == "browser") | .id')

if [ -n "$BROWSER_FLOW_ID" ]; then
  # Check if identity provider redirector already exists in the flow
  REDIRECTOR_EXISTS=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get authentication/flows/${BROWSER_FLOW_ID}/executions -r master | jq -r '.[] | select(.providerId == "identity-provider-redirector") | .id' || echo "")
  
  if [ -z "$REDIRECTOR_EXISTS" ]; then
    echo "Adding identity provider redirector to browser flow..."
    # This is complex to do via CLI, so we'll skip it for now
    echo "Note: You may need to manually configure the authentication flow in Keycloak admin console."
  fi
fi

# Verify the configuration
echo "Verifying Google identity provider configuration..."
GOOGLE_PROVIDER=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get identity-provider/instances/google -r master | jq -r '.alias' || echo "")

if [ "$GOOGLE_PROVIDER" = "google" ]; then
  echo "✓ Google authentication successfully configured in Keycloak"
  echo ""
  echo "Google OAuth2 redirect URI for your application:"
  echo "  http://localhost:8080/realms/master/broker/google/endpoint"
  echo ""
  echo "You can now:"
  echo "  1. Access Keycloak at http://localhost:8080"
  echo "  2. Users will see a 'Sign in with Google' option on the login page"
  echo "  3. Update your Google OAuth application if needed with the redirect URI above"
else
  echo "✗ Failed to configure Google authentication"
  exit 1
fi