#!/bin/bash

echo "=============================================="
echo "Frontend Authentication Debug Script"
echo "=============================================="
echo

echo "1. Checking frontend/.env.local configuration:"
echo "----------------------------------------------"
if [ -f "frontend/.env.local" ]; then
    echo "✓ frontend/.env.local exists"
    echo
    echo "Key environment variables in .env.local:"
    grep -E "^(NEXTAUTH_URL|KEYCLOAK_ISSUER|KEYCLOAK_ISSUER_PUBLIC|KEYCLOAK_CLIENT_ID)=" frontend/.env.local | while read line; do
        echo "  $line"
    done
else
    echo "✗ frontend/.env.local not found!"
    exit 1
fi

echo
echo "2. Checking if frontend container is running:"
echo "----------------------------------------------"
if docker-compose ps frontend | grep -q "Up"; then
    echo "✓ Frontend container is running"
    
    echo
    echo "3. Checking environment variables inside frontend container:"
    echo "-----------------------------------------------------------"
    echo "Environment variables as seen by the frontend container:"
    docker-compose exec -T frontend printenv | grep -E "^(NEXTAUTH_URL|KEYCLOAK_ISSUER|KEYCLOAK_CLIENT_ID)" | sort
    
    echo
    echo "4. Testing NextAuth configuration endpoint:"
    echo "-------------------------------------------"
    echo "Trying to fetch NextAuth configuration..."
    
    # Get the frontend URL from environment
    FRONTEND_URL=$(grep "^NEXTAUTH_URL=" frontend/.env.local | cut -d'=' -f2)
    if [ -z "$FRONTEND_URL" ]; then
        FRONTEND_URL="http://localhost:3005"
    fi
    
    echo "Frontend URL: $FRONTEND_URL"
    echo "Testing NextAuth providers endpoint..."
    
    # Try to get the providers configuration
    curl -s "$FRONTEND_URL/api/auth/providers" | jq '.' 2>/dev/null || echo "Could not fetch or parse providers config"
    
    echo
    echo "5. Testing NextAuth signin URL:"
    echo "-------------------------------"
    echo "Checking what URL NextAuth generates for Keycloak signin..."
    
    # Try to get the signin URL
    SIGNIN_RESPONSE=$(curl -s -I "$FRONTEND_URL/api/auth/signin/keycloak" | head -1)
    echo "Response: $SIGNIN_RESPONSE"
    
    # Check for redirect location
    REDIRECT_URL=$(curl -s -I "$FRONTEND_URL/api/auth/signin/keycloak" | grep -i "location:" | cut -d' ' -f2- | tr -d '\r\n')
    if [ -n "$REDIRECT_URL" ]; then
        echo "Redirect URL: $REDIRECT_URL"
        
        if echo "$REDIRECT_URL" | grep -q "localhost"; then
            echo "⚠️  WARNING: Redirect URL contains 'localhost' - this is the problem!"
        elif echo "$REDIRECT_URL" | grep -q "keycloak-api.joseserver.com"; then
            echo "✓ Redirect URL correctly uses external domain"
        else
            echo "? Redirect URL uses different domain than expected"
        fi
    else
        echo "No redirect URL found in response"
    fi
    
else
    echo "✗ Frontend container is not running"
    echo "Run 'docker-compose up -d frontend' to start it"
    exit 1
fi

echo
echo "6. Checking NextAuth configuration in running container:"
echo "--------------------------------------------------------"
echo "Checking the actual NextAuth route file in the container..."
docker-compose exec -T frontend cat /app/src/app/api/auth/[...nextauth]/route.ts | head -20

echo
echo "7. Recommendations:"
echo "-------------------"
echo "If the redirect URL still contains 'localhost':"
echo "1. Ensure the frontend container was restarted after .env.local changes"
echo "2. Check if there are any cached values in the browser"
echo "3. Try a hard refresh (Ctrl+F5) or incognito mode"
echo "4. Verify the environment variables are correctly loaded in the container"
echo
echo "If the environment variables are wrong in the container:"
echo "1. Stop and restart the entire stack: docker-compose down && docker-compose up -d"
echo "2. Check if there are conflicting environment files"
echo "3. Ensure the .env.local file is properly mounted"