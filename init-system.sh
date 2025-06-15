#!/bin/bash
set -e

echo "=== Initializing On-Behalf-Of Demo System ==="
echo ""

# Wait for consent store to be ready
echo "Waiting for consent store to be ready..."
until curl -s http://localhost:8001/health > /dev/null; do
    sleep 1
done
echo "✓ Consent store is ready"

# Register applications
echo ""
echo "Registering applications..."

# Check if service-a exists
if ! curl -s http://localhost:8001/applications | jq -e '.[] | select(.name=="service-a")' > /dev/null; then
    echo "Registering service-a..."
    curl -X POST http://localhost:8001/applications \
      -H "Content-Type: application/json" \
      -d '{"name": "service-a"}' | jq '.'
else
    echo "service-a already registered"
fi

# Check if service-b exists
if ! curl -s http://localhost:8001/applications | jq -e '.[] | select(.name=="service-b")' > /dev/null; then
    echo "Registering service-b..."
    curl -X POST http://localhost:8001/applications \
      -H "Content-Type: application/json" \
      -d '{"name": "service-b"}' | jq '.'
else
    echo "service-b already registered"
fi

# Get service-b ID
SERVICE_B_ID=$(curl -s http://localhost:8001/applications | jq -r '.[] | select(.name=="service-b") | .id')

# Add capabilities to service-b
echo ""
echo "Adding capabilities to service-b (ID: $SERVICE_B_ID)..."

# Get current capabilities
CURRENT_CAPS=$(curl -s http://localhost:8001/applications/$SERVICE_B_ID | jq -r '.capabilities[]' 2>/dev/null || echo "")

# Add missing capabilities
for cap in "withdraw" "view_balance" "transfer"; do
    if ! echo "$CURRENT_CAPS" | grep -q "^$cap$"; then
        echo "Adding capability: $cap"
        curl -X PUT http://localhost:8001/applications/$SERVICE_B_ID/capabilities \
          -H "Content-Type: application/json" \
          -d "{\"capability\": \"$cap\"}" | jq '.'
    else
        echo "Capability $cap already exists"
    fi
done

echo ""
echo "=== System initialization complete! ==="
echo ""
echo "Applications registered:"
curl -s http://localhost:8001/applications | jq '.'