#!/bin/bash
set -e

echo "Granting test consent for service-a to use service-b withdraw capability..."

# Grant consent for admin user
curl -X POST http://localhost:8001/consent \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "admin",
    "requesting_app_name": "service-a",
    "destination_app_name": "service-b",
    "capabilities": ["withdraw"]
  }'

echo ""
echo "✓ Consent granted for admin user"

# Grant consent for testuser
curl -X POST http://localhost:8001/consent \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "testuser",
    "requesting_app_name": "service-a",
    "destination_app_name": "service-b",
    "capabilities": ["withdraw"]
  }'

echo ""
echo "✓ Consent granted for testuser"
echo ""
echo "Users can now use the 'Empty Bank Account' button successfully!"