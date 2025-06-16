#!/bin/bash

# Setup script for environment configuration

echo "==================================="
echo "Environment Configuration Setup"
echo "==================================="
echo

# Check if .env already exists
if [ -f .env ]; then
    echo "⚠️  Warning: .env file already exists!"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
fi

# Copy .env.example to .env
cp .env.example .env

echo "✅ Created .env file from .env.example"
echo

# Interactive configuration
echo "Would you like to configure the services interactively? (Press Enter to use defaults)"
read -p "Configure now? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo
    echo "Leave blank to use default values:"
    echo
    echo "=== Local Service Configuration ==="
    echo

    # Frontend
    read -p "Frontend port [3005]: " FRONTEND_PORT
    if [ ! -z "$FRONTEND_PORT" ]; then
        sed -i.bak "s/FRONTEND_PORT=.*/FRONTEND_PORT=$FRONTEND_PORT/" .env
    fi

    # Banking Service
    read -p "Banking service host [localhost]: " BANKING_HOST
    if [ ! -z "$BANKING_HOST" ]; then
        sed -i.bak "s/BANKING_SERVICE_HOST=.*/BANKING_SERVICE_HOST=$BANKING_HOST/" .env
    fi

    read -p "Banking service port [8012]: " BANKING_PORT
    if [ ! -z "$BANKING_PORT" ]; then
        sed -i.bak "s/BANKING_SERVICE_PORT=.*/BANKING_SERVICE_PORT=$BANKING_PORT/" .env
    fi

    # Service A
    read -p "Service A host [localhost]: " SERVICE_A_HOST
    if [ ! -z "$SERVICE_A_HOST" ]; then
        sed -i.bak "s/SERVICE_A_HOST=.*/SERVICE_A_HOST=$SERVICE_A_HOST/" .env
    fi

    read -p "Service A port [8004]: " SERVICE_A_PORT
    if [ ! -z "$SERVICE_A_PORT" ]; then
        sed -i.bak "s/SERVICE_A_PORT=.*/SERVICE_A_PORT=$SERVICE_A_PORT/" .env
    fi

    # Consent Store
    read -p "Consent store host [localhost]: " CONSENT_HOST
    if [ ! -z "$CONSENT_HOST" ]; then
        sed -i.bak "s/CONSENT_STORE_HOST=.*/CONSENT_STORE_HOST=$CONSENT_HOST/" .env
    fi

    read -p "Consent store port [8001]: " CONSENT_PORT
    if [ ! -z "$CONSENT_PORT" ]; then
        sed -i.bak "s/CONSENT_STORE_PORT=.*/CONSENT_STORE_PORT=$CONSENT_PORT/" .env
    fi

    # Hello Service
    read -p "Hello service host [localhost]: " HELLO_HOST
    if [ ! -z "$HELLO_HOST" ]; then
        sed -i.bak "s/HELLO_SERVICE_HOST=.*/HELLO_SERVICE_HOST=$HELLO_HOST/" .env
    fi

    read -p "Hello service port [8003]: " HELLO_PORT
    if [ ! -z "$HELLO_PORT" ]; then
        sed -i.bak "s/HELLO_SERVICE_PORT=.*/HELLO_SERVICE_PORT=$HELLO_PORT/" .env
    fi

    echo
    echo "=== External Access Configuration ==="
    echo "Configure how external clients will access each service."
    echo "You can use domain names (e.g., api.example.com) or IP addresses."
    echo "Leave blank to use the default placeholder values."
    echo

    # Choose configuration mode
    echo "Configuration modes:"
    echo "1) Simple - Use one domain/IP for all services (with different ports)"
    echo "2) Advanced - Configure each service URL individually"
    echo
    read -p "Select mode [1]: " CONFIG_MODE
    
    if [ "$CONFIG_MODE" = "2" ]; then
        # Advanced mode - ask for each service
        echo
        echo "--- Authentication Server ---"
        read -p "External URL for Keycloak [http://CHANGE_ME:8080]: " KEYCLOAK_EXTERNAL_URL
        if [ ! -z "$KEYCLOAK_EXTERNAL_URL" ]; then
            sed -i.bak "s|KEYCLOAK_EXTERNAL_URL=.*|KEYCLOAK_EXTERNAL_URL=$KEYCLOAK_EXTERNAL_URL|" .env
        fi

        echo
        echo "--- Frontend Application ---"
        read -p "External URL for Frontend [http://CHANGE_ME:3005]: " FRONTEND_EXTERNAL_URL
        if [ ! -z "$FRONTEND_EXTERNAL_URL" ]; then
            sed -i.bak "s|FRONTEND_EXTERNAL_URL=.*|FRONTEND_EXTERNAL_URL=$FRONTEND_EXTERNAL_URL|" .env
        fi

        echo
        echo "--- API Services ---"
        read -p "External URL for Service A (Main API) [http://CHANGE_ME:8004]: " SERVICE_A_EXTERNAL_URL
        if [ ! -z "$SERVICE_A_EXTERNAL_URL" ]; then
            sed -i.bak "s|SERVICE_A_EXTERNAL_URL=.*|SERVICE_A_EXTERNAL_URL=$SERVICE_A_EXTERNAL_URL|" .env
        fi

        read -p "External URL for Banking Service [http://CHANGE_ME:8012]: " BANKING_SERVICE_EXTERNAL_URL
        if [ ! -z "$BANKING_SERVICE_EXTERNAL_URL" ]; then
            sed -i.bak "s|BANKING_SERVICE_EXTERNAL_URL=.*|BANKING_SERVICE_EXTERNAL_URL=$BANKING_SERVICE_EXTERNAL_URL|" .env
        fi

        read -p "External URL for Consent Store API [http://CHANGE_ME:8001]: " CONSENT_STORE_EXTERNAL_URL
        if [ ! -z "$CONSENT_STORE_EXTERNAL_URL" ]; then
            sed -i.bak "s|CONSENT_STORE_EXTERNAL_URL=.*|CONSENT_STORE_EXTERNAL_URL=$CONSENT_STORE_EXTERNAL_URL|" .env
        fi

        read -p "External URL for Hello Service [http://CHANGE_ME:8003]: " HELLO_SERVICE_EXTERNAL_URL
        if [ ! -z "$HELLO_SERVICE_EXTERNAL_URL" ]; then
            sed -i.bak "s|HELLO_SERVICE_EXTERNAL_URL=.*|HELLO_SERVICE_EXTERNAL_URL=$HELLO_SERVICE_EXTERNAL_URL|" .env
        fi
    else
        # Simple mode - use one domain/IP for all
        echo
        read -p "Domain or IP address for all services [CHANGE_ME]: " BASE_DOMAIN
        if [ ! -z "$BASE_DOMAIN" ]; then
            # Get ports from current configuration
            KEYCLOAK_PORT=$(grep "^KEYCLOAK_PORT=" .env | cut -d'=' -f2 || echo "8080")
            FRONTEND_PORT=$(grep "^FRONTEND_PORT=" .env | cut -d'=' -f2 || echo "3005")
            SERVICE_A_PORT=$(grep "^SERVICE_A_PORT=" .env | cut -d'=' -f2 || echo "8004")
            BANKING_SERVICE_PORT=$(grep "^BANKING_SERVICE_PORT=" .env | cut -d'=' -f2 || echo "8012")
            CONSENT_STORE_PORT=$(grep "^CONSENT_STORE_PORT=" .env | cut -d'=' -f2 || echo "8001")
            HELLO_SERVICE_PORT=$(grep "^HELLO_SERVICE_PORT=" .env | cut -d'=' -f2 || echo "8003")
            
            # Update all external URLs
            sed -i.bak "s|KEYCLOAK_EXTERNAL_URL=.*|KEYCLOAK_EXTERNAL_URL=http://$BASE_DOMAIN:$KEYCLOAK_PORT|" .env
            sed -i.bak "s|FRONTEND_EXTERNAL_URL=.*|FRONTEND_EXTERNAL_URL=http://$BASE_DOMAIN:$FRONTEND_PORT|" .env
            sed -i.bak "s|SERVICE_A_EXTERNAL_URL=.*|SERVICE_A_EXTERNAL_URL=http://$BASE_DOMAIN:$SERVICE_A_PORT|" .env
            sed -i.bak "s|BANKING_SERVICE_EXTERNAL_URL=.*|BANKING_SERVICE_EXTERNAL_URL=http://$BASE_DOMAIN:$BANKING_SERVICE_PORT|" .env
            sed -i.bak "s|CONSENT_STORE_EXTERNAL_URL=.*|CONSENT_STORE_EXTERNAL_URL=http://$BASE_DOMAIN:$CONSENT_STORE_PORT|" .env
            sed -i.bak "s|HELLO_SERVICE_EXTERNAL_URL=.*|HELLO_SERVICE_EXTERNAL_URL=http://$BASE_DOMAIN:$HELLO_SERVICE_PORT|" .env
            
            echo "✅ All services configured to use $BASE_DOMAIN"
        fi
    fi

    # Clean up backup files
    rm -f .env.bak

    echo
    echo "✅ Configuration complete!"
else
    echo "✅ Using default configuration values."
fi

# Configure frontend environment
echo
echo "Configuring frontend environment..."

# Create frontend/.env.local if it doesn't exist
if [ ! -f frontend/.env.local ]; then
    if [ -f frontend/.env.local.example ]; then
        cp frontend/.env.local.example frontend/.env.local
        echo "✅ Created frontend/.env.local from frontend/.env.local.example"
    else
        echo "⚠️  Warning: frontend/.env.local.example not found"
    fi
fi

if [ -f frontend/.env.local ]; then
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Update frontend .env.local with the service URLs from .env
        echo "Updating frontend configuration with service URLs..."
        
        # Extract service URLs
        KEYCLOAK_URL=$(grep "^KEYCLOAK_EXTERNAL_URL=" .env | cut -d'=' -f2)
        FRONTEND_URL=$(grep "^FRONTEND_EXTERNAL_URL=" .env | cut -d'=' -f2)
        SERVICE_A_URL=$(grep "^SERVICE_A_EXTERNAL_URL=" .env | cut -d'=' -f2)
        CONSENT_STORE_URL=$(grep "^CONSENT_STORE_EXTERNAL_URL=" .env | cut -d'=' -f2)
        HELLO_SERVICE_URL=$(grep "^HELLO_SERVICE_EXTERNAL_URL=" .env | cut -d'=' -f2)
        
        # Update frontend .env.local with actual URLs
        if [ ! -z "$KEYCLOAK_URL" ] && [ "$KEYCLOAK_URL" != "http://CHANGE_ME:8080" ]; then
            # Update KEYCLOAK_ISSUER_PUBLIC
            sed -i.bak "s|KEYCLOAK_ISSUER_PUBLIC=.*|KEYCLOAK_ISSUER_PUBLIC=$KEYCLOAK_URL/realms/master|" frontend/.env.local
        fi
        
        if [ ! -z "$FRONTEND_URL" ] && [ "$FRONTEND_URL" != "http://CHANGE_ME:3005" ]; then
            # Update NEXTAUTH_URL
            sed -i.bak "s|NEXTAUTH_URL=.*|NEXTAUTH_URL=$FRONTEND_URL|" frontend/.env.local
        fi
        
        if [ ! -z "$SERVICE_A_URL" ] && [ "$SERVICE_A_URL" != "http://CHANGE_ME:8004" ]; then
            # Update NEXT_PUBLIC_SERVICE_A_URL
            sed -i.bak "s|NEXT_PUBLIC_SERVICE_A_URL=.*|NEXT_PUBLIC_SERVICE_A_URL=$SERVICE_A_URL|" frontend/.env.local
        fi
        
        if [ ! -z "$CONSENT_STORE_URL" ] && [ "$CONSENT_STORE_URL" != "http://CHANGE_ME:8001" ]; then
            # Update NEXT_PUBLIC_CONSENT_STORE_URL
            sed -i.bak "s|NEXT_PUBLIC_CONSENT_STORE_URL=.*|NEXT_PUBLIC_CONSENT_STORE_URL=$CONSENT_STORE_URL|" frontend/.env.local
        fi
        
        if [ ! -z "$HELLO_SERVICE_URL" ] && [ "$HELLO_SERVICE_URL" != "http://CHANGE_ME:8003" ]; then
            # Update NEXT_PUBLIC_HELLO_SERVICE_URL
            sed -i.bak "s|NEXT_PUBLIC_HELLO_SERVICE_URL=.*|NEXT_PUBLIC_HELLO_SERVICE_URL=$HELLO_SERVICE_URL|" frontend/.env.local
        fi
        
        rm -f frontend/.env.local.bak
        echo "✅ Frontend configuration updated!"
    else
        echo "⚠️  Frontend .env.local contains placeholder values."
        echo "   Please edit frontend/.env.local manually to configure service URLs."
    fi
else
    echo "⚠️  Frontend .env.local not found. Please create it from frontend/.env.local.example"
fi

echo
echo "Your environment is now configured!"
echo "You can edit the .env file manually at any time."
echo
echo "To start the services with your configuration, run:"
echo "  make setup"
echo