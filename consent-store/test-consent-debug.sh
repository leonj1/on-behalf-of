#\!/bin/bash
set -e

echo "=== Debugging Consent Flow ==="
echo ""

# Test JWT token
TEST_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0dXNlciIsImVtYWlsIjoidGVzdHVzZXJAZXhhbXBsZS5jb20iLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJ0ZXN0dXNlciJ9.test"

echo "1. Simulating consent grant..."
CONSENT_DATA='{
  "decision": "grant",
  "requesting_service": "service-a",
  "operations": ["withdraw"],
  "state": "test-state-123"
}'

RESPONSE=$(curl -s -X POST http://localhost:8012/consent/decision \
  -H "Authorization: Bearer $TEST_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$CONSENT_DATA")

echo "Consent decision response: $RESPONSE"
echo ""

echo "2. Retrying Service A with consent..."
curl -s -X POST http://localhost:8004/withdraw \
  -H "Authorization: Bearer $TEST_TOKEN" \
  -H "Content-Type: application/json"  < /dev/null |  jq '.'

echo ""
echo "3. Checking service logs..."
echo "=== Service A Logs ==="
docker logs service-a --tail 5 2>&1 | grep -E "(Checking consent|Consent check response)" || echo "No consent logs found"
