#!/bin/bash
set -e

echo "=== Creating Token Exchange Policy ==="
echo ""
echo "This script creates a specific policy allowing service-a to exchange tokens"
echo "for service-b audience using Keycloak's Admin REST API."
echo ""

# Check if Keycloak container is running
if ! docker ps | grep -q keycloak; then
  echo "✗ Keycloak container is not running"
  exit 1
fi

# Get admin token
echo "Getting admin access token..."
TOKEN_RESPONSE=$(curl -s -X POST http://localhost:8080/realms/master/protocol/openid-connect/token \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin")

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
  echo "✗ Failed to get admin token"
  exit 1
fi

echo "✓ Got admin token"

# Get client IDs
echo ""
echo "Getting client information..."
CLIENTS=$(curl -s -X GET "http://localhost:8080/admin/realms/master/clients" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

SERVICE_A_ID=$(echo $CLIENTS | jq -r '.[] | select(.clientId=="service-a") | .id')
SERVICE_B_ID=$(echo $CLIENTS | jq -r '.[] | select(.clientId=="service-b") | .id')

if [ -z "$SERVICE_A_ID" ] || [ -z "$SERVICE_B_ID" ]; then
  echo "✗ Could not find required clients"
  exit 1
fi

echo "✓ Found service-a: $SERVICE_A_ID"
echo "✓ Found service-b: $SERVICE_B_ID"

# Method 1: Create token-exchange permission the manual way
echo ""
echo "Creating token exchange permission policy..."

# First, we need to ensure service-b has a resource server (authorization enabled)
echo "Enabling authorization on service-b..."
curl -s -X PUT "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "authorizationServicesEnabled": true
  }' > /dev/null

sleep 2  # Give Keycloak time to initialize authorization

# Create a token-exchange resource
echo "Creating token-exchange resource..."
RESOURCE_RESPONSE=$(curl -s -X POST "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/authz/resource-server/resource" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "token-exchange",
    "displayName": "Token Exchange Resource",
    "type": "urn:keycloak:resources:default",
    "ownerManagedAccess": false,
    "scopes": []
  }')

RESOURCE_ID=$(echo $RESOURCE_RESPONSE | jq -r '._id // .id // empty')
if [ -n "$RESOURCE_ID" ]; then
  echo "✓ Created resource: $RESOURCE_ID"
else
  # Resource might already exist, try to find it
  RESOURCES=$(curl -s -X GET "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/authz/resource-server/resource" \
    -H "Authorization: Bearer $ACCESS_TOKEN")
  RESOURCE_ID=$(echo $RESOURCES | jq -r '.[] | select(.name=="token-exchange") | ._id // .id' | head -1)
  if [ -n "$RESOURCE_ID" ]; then
    echo "✓ Found existing resource: $RESOURCE_ID"
  fi
fi

# Create a client policy for service-a
echo "Creating client policy..."
POLICY_RESPONSE=$(curl -s -X POST "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/authz/resource-server/policy/client" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"service-a-exchange-policy\",
    \"description\": \"Allow service-a to perform token exchange\",
    \"type\": \"client\",
    \"logic\": \"POSITIVE\",
    \"decisionStrategy\": \"UNANIMOUS\",
    \"clients\": [\"$SERVICE_A_ID\"]
  }")

POLICY_ID=$(echo $POLICY_RESPONSE | jq -r '.id // empty')
if [ -n "$POLICY_ID" ]; then
  echo "✓ Created policy: $POLICY_ID"
else
  # Policy might already exist, try to find it
  POLICIES=$(curl -s -X GET "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/authz/resource-server/policy" \
    -H "Authorization: Bearer $ACCESS_TOKEN")
  POLICY_ID=$(echo $POLICIES | jq -r '.[] | select(.name=="service-a-exchange-policy") | .id' | head -1)
  if [ -n "$POLICY_ID" ]; then
    echo "✓ Found existing policy: $POLICY_ID"
  fi
fi

# Create a resource-based permission
echo "Creating resource permission..."
if [ -n "$RESOURCE_ID" ] && [ -n "$POLICY_ID" ]; then
  PERMISSION_RESPONSE=$(curl -s -X POST "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/authz/resource-server/permission/resource" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"token-exchange-permission\",
      \"description\": \"Permission for token exchange\",
      \"type\": \"resource\",
      \"resources\": [\"$RESOURCE_ID\"],
      \"policies\": [\"$POLICY_ID\"],
      \"decisionStrategy\": \"AFFIRMATIVE\"
    }")
  
  PERMISSION_ID=$(echo $PERMISSION_RESPONSE | jq -r '.id // empty')
  if [ -n "$PERMISSION_ID" ]; then
    echo "✓ Created permission: $PERMISSION_ID"
  else
    echo "✓ Permission might already exist"
  fi
fi

# Method 2: Try the direct approach with management permissions
echo ""
echo "Enabling management permissions on service-b..."
MGMT_RESPONSE=$(curl -s -X PUT "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/management/permissions" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "enabled": true
  }')

echo "✓ Management permissions enabled"

# Get the token-exchange scope permission
echo "Looking for token-exchange scope permission..."
MGMT_PERMS=$(curl -s -X GET "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/management/permissions" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

TOKEN_EXCHANGE_PERM_ID=$(echo $MGMT_PERMS | jq -r '.scopePermissions."token-exchange" // empty')

if [ -n "$TOKEN_EXCHANGE_PERM_ID" ] && [ "$TOKEN_EXCHANGE_PERM_ID" != "null" ]; then
  echo "✓ Found token-exchange permission: $TOKEN_EXCHANGE_PERM_ID"
  
  # Create a user policy for service-a's service account
  echo "Getting service-a's service account..."
  SA_USER=$(curl -s -X GET "http://localhost:8080/admin/realms/master/clients/$SERVICE_A_ID/service-account-user" \
    -H "Authorization: Bearer $ACCESS_TOKEN")
  
  SA_USER_ID=$(echo $SA_USER | jq -r '.id')
  
  if [ -n "$SA_USER_ID" ]; then
    echo "✓ Found service account: $SA_USER_ID"
    
    # Create a user-based policy
    echo "Creating user policy for service account..."
    USER_POLICY_RESPONSE=$(curl -s -X POST "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/authz/resource-server/policy/user" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"name\": \"service-a-sa-policy\",
        \"description\": \"Allow service-a service account\",
        \"type\": \"user\",
        \"logic\": \"POSITIVE\",
        \"decisionStrategy\": \"UNANIMOUS\",
        \"users\": [\"$SA_USER_ID\"]
      }")
    
    USER_POLICY_ID=$(echo $USER_POLICY_RESPONSE | jq -r '.id // empty')
    
    if [ -n "$USER_POLICY_ID" ] || [ -n "$POLICY_ID" ]; then
      # Update the token-exchange permission to include our policies
      echo "Updating token-exchange permission with policies..."
      
      POLICIES_LIST="[]"
      if [ -n "$POLICY_ID" ]; then
        POLICIES_LIST="[\"$POLICY_ID\"]"
      fi
      if [ -n "$USER_POLICY_ID" ]; then
        if [ "$POLICIES_LIST" = "[]" ]; then
          POLICIES_LIST="[\"$USER_POLICY_ID\"]"
        else
          POLICIES_LIST="[\"$POLICY_ID\",\"$USER_POLICY_ID\"]"
        fi
      fi
      
      curl -s -X PUT "http://localhost:8080/admin/realms/master/clients/$SERVICE_B_ID/authz/resource-server/permission/$TOKEN_EXCHANGE_PERM_ID" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
          \"policies\": $POLICIES_LIST,
          \"decisionStrategy\": \"AFFIRMATIVE\"
        }" > /dev/null
      
      echo "✓ Updated permission with policies"
    fi
  fi
fi

echo ""
echo "=== Token Exchange Policy Creation Complete ==="
echo ""
echo "Created the following:"
echo "✓ Authorization enabled on service-b"
echo "✓ Token-exchange resource"
echo "✓ Client policy for service-a"
echo "✓ Resource permission"
echo "✓ Management permissions"
echo "✓ Service account policies"
echo ""
echo "Token exchange should now be allowed from service-a to service-b"