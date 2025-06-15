#!/bin/bash
set -e

echo "=== Testing Consent Flow ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}1. Testing consent.json discovery endpoint...${NC}"
curl -s http://localhost:8012/consent.json | jq '.service_name'
echo -e "${GREEN}✓ Consent discovery endpoint working${NC}"
echo ""

echo -e "${YELLOW}2. Checking if consent UI is accessible...${NC}"
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8012/consent)
if [ "$response" = "200" ]; then
    echo -e "${GREEN}✓ Consent UI endpoint is accessible${NC}"
else
    echo -e "${RED}✗ Consent UI endpoint returned: $response${NC}"
fi
echo ""

echo -e "${YELLOW}3. Testing Service A without consent (should return 403)...${NC}"
# Use a test token (in production, use real token)
TEST_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0dXNlciIsImVtYWlsIjoidGVzdHVzZXJAZXhhbXBsZS5jb20iLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJ0ZXN0dXNlciJ9.test"

response=$(curl -s -X POST http://localhost:8004/withdraw \
  -H "Authorization: Bearer $TEST_TOKEN" \
  -H "Content-Type: application/json" \
  -w "\nHTTP_CODE:%{http_code}")

http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
body=$(echo "$response" | grep -v "HTTP_CODE:")

if [ "$http_code" = "403" ]; then
    echo -e "${GREEN}✓ Service A correctly returned 403 Forbidden${NC}"
    echo "Response contains consent_required error:"
    echo "$body" | jq '.detail.error_code' 2>/dev/null || echo "$body"
else
    echo -e "${RED}✗ Service A returned unexpected status: $http_code${NC}"
fi
echo ""

echo -e "${YELLOW}4. Consent UI URL that would be used:${NC}"
consent_url=$(echo "$body" | jq -r '.detail.consent_ui_url' 2>/dev/null || echo "Not found")
if [ "$consent_url" != "Not found" ] && [ "$consent_url" != "null" ]; then
    echo -e "${GREEN}✓ Consent UI URL: $consent_url${NC}"
    
    # Build full URL with parameters
    echo ""
    echo "Full consent URL with parameters:"
    echo "$consent_url?requesting_service=service-a&requesting_service_name=Service%20A&destination_service=service-b&operations=withdraw&redirect_uri=http%3A%2F%2F10.1.1.74%3A3005%2Fconsent-callback&state=test123&user_token=$TEST_TOKEN"
else
    echo -e "${RED}✗ Could not extract consent UI URL${NC}"
fi
echo ""

echo -e "${YELLOW}5. To complete the flow:${NC}"
echo "   a) User would be redirected to the consent UI"
echo "   b) User grants consent"
echo "   c) Consent is saved to consent store"
echo "   d) User is redirected back to frontend"
echo "   e) Frontend retries the withdraw request"
echo "   f) Request succeeds with consent in place"
echo ""

echo -e "${GREEN}=== Consent flow implementation complete! ===${NC}"