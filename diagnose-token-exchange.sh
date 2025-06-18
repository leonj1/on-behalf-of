#!/bin/bash
set -e

echo "=== Token Exchange Diagnostics ==="
echo ""

# Check if Keycloak container is running
if ! docker ps | grep -q keycloak; then
  echo "✗ Keycloak container is not running"
  exit 1
fi

# Check Keycloak version
echo "1. Keycloak Version:"
docker exec keycloak /opt/keycloak/bin/kc.sh --version 2>/dev/null || docker exec keycloak /opt/keycloak/bin/kc.sh version 2>/dev/null || echo "  Could not determine version"
echo ""

# Check if token-exchange feature is enabled
echo "2. Checking if token-exchange feature is enabled:"
docker exec keycloak /bin/bash -c 'ps aux | grep -o "features=token-exchange" || echo "  Feature flag not found in process"'
echo ""

# Authenticate
docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin \
  --client admin-cli > /dev/null 2>&1

# Check realm configuration
echo "3. Realm Configuration:"
REALM_CONFIG=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get realms/master -r master)
echo "  Token Exchange attribute: $(echo $REALM_CONFIG | jq -r '.attributes.tokenExchangeEnabled // "not set"')"
echo "  Token Exchange attribute (alt): $(echo $REALM_CONFIG | jq -r '.attributes.tokenExchange // "not set"')"
echo ""

# Check service-a client configuration
echo "4. Service-a Client Configuration:"
SERVICE_A_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="service-a") | .id')
if [ -n "$SERVICE_A_UUID" ]; then
  CLIENT_CONFIG=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_A_UUID -r master)
  echo "  Service Accounts Enabled: $(echo $CLIENT_CONFIG | jq -r '.serviceAccountsEnabled')"
  echo "  Direct Access Grants: $(echo $CLIENT_CONFIG | jq -r '.directAccessGrantsEnabled')"
  echo "  Public Client: $(echo $CLIENT_CONFIG | jq -r '.publicClient')"
  echo "  Full Scope Allowed: $(echo $CLIENT_CONFIG | jq -r '.fullScopeAllowed')"
  echo "  Token Exchange Enabled: $(echo $CLIENT_CONFIG | jq -r '.attributes."token.exchange.grant.enabled" // "not set"')"
  echo "  Token Exchange Permissions: $(echo $CLIENT_CONFIG | jq -r '.attributes."token-exchange-permissions-enabled" // "not set"')"
  
  # Check service account roles
  echo ""
  echo "5. Service Account Roles:"
  SA_USER=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_A_UUID/service-account-user -r master 2>/dev/null | jq -r '.id' || echo "")
  if [ -n "$SA_USER" ]; then
    ROLES=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get users/$SA_USER/role-mappings -r master 2>/dev/null || echo "{}")
    echo "  Realm roles: $(echo $ROLES | jq -r '.realmMappings[].name' 2>/dev/null | tr '\n' ', ' || echo "none")"
    echo "  Client roles: $(echo $ROLES | jq -r '.clientMappings | to_entries[] | "\(.key): \(.value[].name)"' 2>/dev/null | tr '\n' ', ' || echo "none")"
  fi
fi

# Check service-b configuration
echo ""
echo "6. Service-b Client Configuration:"
SERVICE_B_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="service-b") | .id')
if [ -n "$SERVICE_B_UUID" ]; then
  CLIENT_CONFIG=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_B_UUID -r master)
  echo "  Authorization Services Enabled: $(echo $CLIENT_CONFIG | jq -r '.authorizationServicesEnabled')"
  
  # Check if management permissions are enabled
  MGMT_PERMS=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_B_UUID/management/permissions -r master 2>/dev/null || echo "{}")
  echo "  Management Permissions Enabled: $(echo $MGMT_PERMS | jq -r '.enabled // false')"
  
  # Check authorization settings if enabled
  if [ "$(echo $CLIENT_CONFIG | jq -r '.authorizationServicesEnabled')" = "true" ]; then
    echo ""
    echo "7. Authorization Configuration:"
    # Check for token-exchange permission
    PERMS=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_B_UUID/authz/resource-server/permission -r master 2>/dev/null || echo "[]")
    echo "  Token exchange permissions: $(echo $PERMS | jq -r '.[] | select(.name | contains("token-exchange")) | .name' | tr '\n' ', ' || echo "none found")"
    
    # Check for policies
    POLICIES=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_B_UUID/authz/resource-server/policy -r master 2>/dev/null || echo "[]")
    echo "  Policies for service-a: $(echo $POLICIES | jq -r '.[] | select(.config.clients // "" | contains("service-a")) | .name' | tr '\n' ', ' || echo "none found")"
  fi
fi

echo ""
echo "8. Testing Token Exchange:"
# Try to get a test token and perform exchange
if [ -n "$SERVICE_A_UUID" ]; then
  SECRET=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$SERVICE_A_UUID/client-secret -r master 2>/dev/null | jq -r '.value' || echo "")
  if [ -n "$SECRET" ]; then
    echo "  Getting service account token..."
    TOKEN_RESPONSE=$(curl -s -X POST http://localhost:8080/realms/master/protocol/openid-connect/token \
      -d "grant_type=client_credentials" \
      -d "client_id=service-a" \
      -d "client_secret=$SECRET" 2>/dev/null || echo "{}")
    
    ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token // empty' || echo "")
    if [ -n "$ACCESS_TOKEN" ]; then
      echo "  ✓ Got service account token"
      
      echo "  Attempting token exchange to banking-service..."
      EXCHANGE_RESPONSE=$(curl -s -X POST http://localhost:8080/realms/master/protocol/openid-connect/token \
        -d "grant_type=urn:ietf:params:oauth:grant-type:token-exchange" \
        -d "subject_token=$ACCESS_TOKEN" \
        -d "subject_token_type=urn:ietf:params:oauth:token-type:access_token" \
        -d "requested_token_type=urn:ietf:params:oauth:token-type:access_token" \
        -d "audience=banking-service" \
        -d "client_id=service-a" \
        -d "client_secret=$SECRET" 2>/dev/null || echo "{}")
      
      ERROR=$(echo $EXCHANGE_RESPONSE | jq -r '.error // empty' || echo "")
      if [ -n "$ERROR" ]; then
        echo "  ✗ Token exchange failed: $ERROR"
        echo "    $(echo $EXCHANGE_RESPONSE | jq -r '.error_description // empty')"
      else
        EXCHANGED_TOKEN=$(echo $EXCHANGE_RESPONSE | jq -r '.access_token // empty' || echo "")
        if [ -n "$EXCHANGED_TOKEN" ]; then
          echo "  ✓ Token exchange successful!"
        else
          echo "  ✗ Unexpected response: $EXCHANGE_RESPONSE"
        fi
      fi
    else
      echo "  ✗ Could not get service account token"
    fi
  else
    echo "  ✗ Could not get client secret"
  fi
fi

echo ""
echo "=== Diagnostics Complete ==="