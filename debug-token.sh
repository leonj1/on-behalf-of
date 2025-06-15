#!/bin/bash

echo "=== Debugging Token User IDs ==="
echo ""

# Get a fresh token
CLIENT_SECRET="wke7pQorLPoBfnIAcoDKPUQr5eLlGCf1"
TOKEN_RESPONSE=$(curl -s -X POST http://localhost:8080/realms/master/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=nextjs-app" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "username=admin" \
  -d "password=admin" \
  -d "scope=openid profile email")

if echo "$TOKEN_RESPONSE" | grep -q "access_token"; then
    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
    
    echo "1. Decoding JWT token..."
    # Decode the payload
    PAYLOAD=$(echo "$ACCESS_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null)
    
    echo "Token payload:"
    echo "$PAYLOAD" | jq '.'
    
    echo ""
    echo "2. Key fields:"
    echo "sub (user ID): $(echo "$PAYLOAD" | jq -r '.sub')"
    echo "email: $(echo "$PAYLOAD" | jq -r '.email')"
    echo "preferred_username: $(echo "$PAYLOAD" | jq -r '.preferred_username')"
    echo "aud (audience): $(echo "$PAYLOAD" | jq -r '.aud')"
    
    echo ""
    echo "3. Testing what user ID is used in consent..."
    # Grant a test consent
    curl -s -X POST http://localhost:8012/consent/decision \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{
        "decision": "grant",
        "requesting_service": "service-a",
        "operations": ["view_balance"],
        "state": "test-debug"
      }' | jq '.'
    
    echo ""
    echo "4. Check recent banking service logs for user_id..."
    docker logs banking-service --tail 5 2>&1 | grep "Saving consent" | tail -1
    
else
    echo "Failed to get token"
fi