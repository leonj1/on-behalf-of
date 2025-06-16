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
    echo "Configure how external clients will access your services"
    echo

    # External IPs
    read -p "External IP for backend services [CHANGE_ME_IP]: " EXTERNAL_IP
    if [ ! -z "$EXTERNAL_IP" ]; then
        sed -i.bak "s/EXTERNAL_IP=.*/EXTERNAL_IP=$EXTERNAL_IP/" .env
    else
        EXTERNAL_IP="CHANGE_ME_IP"
    fi

    read -p "External IP for frontend access [CHANGE_ME_FRONTEND_IP]: " FRONTEND_EXTERNAL_IP
    if [ ! -z "$FRONTEND_EXTERNAL_IP" ]; then
        sed -i.bak "s/FRONTEND_EXTERNAL_IP=.*/FRONTEND_EXTERNAL_IP=$FRONTEND_EXTERNAL_IP/" .env
        # Auto-update FRONTEND_EXTERNAL_URL
        FRONTEND_PORT_VALUE=$(grep "^FRONTEND_PORT=" .env | cut -d'=' -f2)
        sed -i.bak "s|FRONTEND_EXTERNAL_URL=.*|FRONTEND_EXTERNAL_URL=http://$FRONTEND_EXTERNAL_IP:${FRONTEND_PORT_VALUE:-3005}|" .env
    else
        FRONTEND_EXTERNAL_IP="CHANGE_ME_FRONTEND_IP"
    fi

    # Keycloak Configuration
    echo
    echo "=== Keycloak Configuration ==="
    echo

    read -p "Keycloak host [localhost]: " KEYCLOAK_HOST
    if [ ! -z "$KEYCLOAK_HOST" ]; then
        sed -i.bak "s/KEYCLOAK_HOST=.*/KEYCLOAK_HOST=$KEYCLOAK_HOST/" .env
    fi

    read -p "Keycloak port [8080]: " KEYCLOAK_PORT
    if [ ! -z "$KEYCLOAK_PORT" ]; then
        sed -i.bak "s/KEYCLOAK_PORT=.*/KEYCLOAK_PORT=$KEYCLOAK_PORT/" .env
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
if [ -f frontend/.env.local ]; then
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Update frontend .env.local with the values from .env
        EXTERNAL_IP_VALUE=$(grep "^EXTERNAL_IP=" .env | cut -d'=' -f2)
        FRONTEND_EXTERNAL_IP_VALUE=$(grep "^FRONTEND_EXTERNAL_IP=" .env | cut -d'=' -f2)
        
        if [ "$EXTERNAL_IP_VALUE" != "CHANGE_ME_IP" ] && [ ! -z "$EXTERNAL_IP_VALUE" ]; then
            sed -i.bak "s/CHANGE_ME_IP/$EXTERNAL_IP_VALUE/g" frontend/.env.local
        fi
        
        if [ "$FRONTEND_EXTERNAL_IP_VALUE" != "CHANGE_ME_FRONTEND_IP" ] && [ ! -z "$FRONTEND_EXTERNAL_IP_VALUE" ]; then
            sed -i.bak "s/CHANGE_ME_FRONTEND_IP/$FRONTEND_EXTERNAL_IP_VALUE/g" frontend/.env.local
        fi
        
        rm -f frontend/.env.local.bak
        
        if [ "$EXTERNAL_IP_VALUE" != "CHANGE_ME_IP" ] || [ "$FRONTEND_EXTERNAL_IP_VALUE" != "CHANGE_ME_FRONTEND_IP" ]; then
            echo "✅ Frontend configuration updated!"
        else
            echo "⚠️  Frontend .env.local still contains placeholder values."
            echo "   Please configure external IPs first or edit frontend/.env.local manually."
        fi
    else
        echo "⚠️  Frontend .env.local contains placeholder values."
        echo "   Please edit frontend/.env.local manually to replace CHANGE_ME_* values."
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