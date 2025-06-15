#!/bin/bash
set -e

echo "=== Registering Applications in Consent Store ==="
echo ""

# Register service-a
echo "1. Registering service-a..."
curl -X POST http://localhost:8001/applications \
  -H "Content-Type: application/json" \
  -d '{"name": "service-a"}' | jq '.'

echo ""
echo "2. Registering service-b (banking-service)..."
curl -X POST http://localhost:8001/applications \
  -H "Content-Type: application/json" \
  -d '{"name": "service-b"}' | jq '.'

echo ""
echo "3. Adding capabilities to service-b (ID 2)..."
# Add withdraw capability
curl -X PUT http://localhost:8001/applications/2/capabilities \
  -H "Content-Type: application/json" \
  -d '{"capability": "withdraw"}' | jq '.'

# Add view_balance capability
curl -X PUT http://localhost:8001/applications/2/capabilities \
  -H "Content-Type: application/json" \
  -d '{"capability": "view_balance"}' | jq '.'

# Add transfer capability
curl -X PUT http://localhost:8001/applications/2/capabilities \
  -H "Content-Type: application/json" \
  -d '{"capability": "transfer"}' | jq '.'

echo ""
echo "4. Verifying applications..."
echo "All applications:"
curl -s http://localhost:8001/applications | jq '.'
echo ""
echo "Service B capabilities:"
curl -s http://localhost:8001/applications/2 | jq '.'

echo ""
echo "=== Applications registered successfully! ==="