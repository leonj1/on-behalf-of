#!/bin/bash
set -e

echo "=== Testing Full Consent Flow with Real Token ==="
echo ""

# First, let's get a real token from Keycloak
echo "1. Getting access token from Keycloak..."
CLIENT_SECRET="wke7pQorLPoBfnIAcoDKPUQr5eLlGCf1"
TOKEN_RESPONSE=$(curl -s -X POST http://localhost:8080/realms/master/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=nextjs-app" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "username=admin" \
  -d "password=admin" \
  -d "scope=openid profile email" 2>/dev/null || echo '{"error": "Failed to get token"}')

if echo "$TOKEN_RESPONSE" | grep -q "access_token"; then
    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
    echo "✓ Got access token"
    
    # Decode token to see audience
    echo ""
    echo "Token payload (audience check):"
    echo "$ACCESS_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq '.aud' || echo "Could not decode"
else
    echo "✗ Failed to get token: $TOKEN_RESPONSE"
    echo "Using test token instead..."
    ACCESS_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0dXNlciIsImVtYWlsIjoidGVzdHVzZXJAZXhhbXBsZS5jb20iLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJ0ZXN0dXNlciJ9.test"
fi

echo ""
echo "2. First attempt - should get consent required..."
RESPONSE=$(curl -s -X POST http://localhost:8004/withdraw \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json")

if echo "$RESPONSE" | jq -e '.detail.error_code == "consent_required"' > /dev/null; then
    echo "✓ Got consent required response"
    STATE=$(echo "$RESPONSE" | jq -r '.detail.consent_params.state')
    echo "State token: $STATE"
else
    echo "Unexpected response:"
    echo "$RESPONSE" | jq '.'
fi

echo ""
echo "3. Granting consent..."
CONSENT_RESPONSE=$(curl -s -X POST http://localhost:8012/consent/decision \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "decision": "grant",
    "requesting_service": "service-a",
    "operations": ["withdraw"],
    "state": "'$STATE'"
  }')

echo "Consent response: $CONSENT_RESPONSE"

echo ""
echo "4. Retrying withdrawal with consent..."
WITHDRAW_RESPONSE=$(curl -s -X POST http://localhost:8004/withdraw \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json")

echo "Withdrawal response:"
echo "$WITHDRAW_RESPONSE" | jq '.'

echo ""
echo "5. Checking logs for debugging..."
echo "=== Service A logs ==="
docker logs service-a --tail 10 2>&1 | grep -E "(Token exchange|audience|Checking consent)" || echo "No relevant logs"

echo ""
echo "=== Banking Service logs ==="
docker logs banking-service --tail 10 2>&1 | grep -E "(audience|Invalid|Expected)" || echo "No relevant logs"