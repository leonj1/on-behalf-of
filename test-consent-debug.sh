#!/bin/bash
set -e

echo "=== Debugging Consent Flow ==="
echo ""

# Test JWT token
TEST_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0dXNlciIsImVtYWlsIjoidGVzdHVzZXJAZXhhbXBsZS5jb20iLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJ0ZXN0dXNlciJ9.test"

echo "1. Calling Service A without consent..."
curl -s -X POST http://localhost:8004/withdraw \
  -H "Authorization: Bearer $TEST_TOKEN" \
  -H "Content-Type: application/json" | jq '.'

echo ""
echo "2. Simulating consent grant..."
CONSENT_DATA='{
  "decision": "grant",
  "requesting_service": "service-a",
  "operations": ["withdraw"],
  "state": "test-state-123"
}'

echo "Sending: $CONSENT_DATA"
echo ""

RESPONSE=$(curl -s -X POST http://localhost:8012/consent/decision \
  -H "Authorization: Bearer $TEST_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$CONSENT_DATA")

echo "Consent decision response: $RESPONSE"
echo ""

echo "3. Checking consent-store directly..."
curl -s "http://localhost:8001/consent/check?user_id=testuser&requesting_app_name=service-a&destination_app_name=service-b&capabilities=withdraw" | jq '.'

echo ""
echo "4. Retrying Service A with consent..."
curl -s -X POST http://localhost:8004/withdraw \
  -H "Authorization: Bearer $TEST_TOKEN" \
  -H "Content-Type: application/json" | jq '.'

echo ""
echo "5. Checking service logs for debug info..."
echo "=== Banking Service Logs ==="
docker logs banking-service --tail 10 2>&1 | grep -E "(Saving consent|Consent store response)" || echo "No consent logs found"

echo ""
echo "=== Service A Logs ==="
docker logs service-a --tail 10 2>&1 | grep -E "(Checking consent|Consent check response)" || echo "No consent logs found"