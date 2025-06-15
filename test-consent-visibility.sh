#!/bin/bash

echo "=== Testing Consent Visibility ==="
echo ""

# First check what consents exist
echo "1. Checking all user consents in the system..."

# Try common user IDs
USER_IDS=(
  "bb1fb3ae-1b5c-4482-b899-600b7f255808"  # From our earlier test
  "f5528c67-3c0e-4650-8aee-8aacb8a40393"  # From another test
  "admin"
  "admin@example.com"
)

for uid in "${USER_IDS[@]}"; do
  echo ""
  echo "Checking user ID: $uid"
  RESPONSE=$(curl -s http://localhost:8001/consent/user/$uid)
  if [ "$RESPONSE" != "[]" ] && [ -n "$RESPONSE" ]; then
    echo "Found consents:"
    echo "$RESPONSE" | jq '.'
  fi
done

echo ""
echo "2. Frontend should be accessible at: http://localhost:3005/consent"
echo "3. Check browser console for 'Fetching consents for user ID:' message"
echo ""
echo "4. To manually test, you can grant a consent and check which user ID is used:"
echo "   - Sign in to frontend"
echo "   - Click 'Empty Bank Account' to trigger consent flow"
echo "   - Grant consent"
echo "   - Go to Manage Consents page"
echo "   - Check browser console for the user ID being used"