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

    # Frontend
    read -p "Frontend port [3005]: " FRONTEND_PORT
    if [ ! -z "$FRONTEND_PORT" ]; then
        sed -i.bak "s/FRONTEND_PORT=.*/FRONTEND_PORT=$FRONTEND_PORT/" .env
    fi

    # Banking Service
    read -p "Banking service host [100.68.45.127]: " BANKING_HOST
    if [ ! -z "$BANKING_HOST" ]; then
        sed -i.bak "s/BANKING_SERVICE_HOST=.*/BANKING_SERVICE_HOST=$BANKING_HOST/" .env
    fi

    read -p "Banking service port [8080]: " BANKING_PORT
    if [ ! -z "$BANKING_PORT" ]; then
        sed -i.bak "s/BANKING_SERVICE_PORT=.*/BANKING_SERVICE_PORT=$BANKING_PORT/" .env
    fi

    # Service A
    read -p "Service A host [localhost]: " SERVICE_A_HOST
    if [ ! -z "$SERVICE_A_HOST" ]; then
        sed -i.bak "s/SERVICE_A_HOST=.*/SERVICE_A_HOST=$SERVICE_A_HOST/" .env
    fi

    read -p "Service A port [8001]: " SERVICE_A_PORT
    if [ ! -z "$SERVICE_A_PORT" ]; then
        sed -i.bak "s/SERVICE_A_PORT=.*/SERVICE_A_PORT=$SERVICE_A_PORT/" .env
    fi

    # Consent Store
    read -p "Consent store host [10.1.1.74]: " CONSENT_HOST
    if [ ! -z "$CONSENT_HOST" ]; then
        sed -i.bak "s/CONSENT_STORE_HOST=.*/CONSENT_STORE_HOST=$CONSENT_HOST/" .env
    fi

    read -p "Consent store port [8003]: " CONSENT_PORT
    if [ ! -z "$CONSENT_PORT" ]; then
        sed -i.bak "s/CONSENT_STORE_PORT=.*/CONSENT_STORE_PORT=$CONSENT_PORT/" .env
    fi

    # Hello Service
    read -p "Hello service host [localhost]: " HELLO_HOST
    if [ ! -z "$HELLO_HOST" ]; then
        sed -i.bak "s/HELLO_SERVICE_HOST=.*/HELLO_SERVICE_HOST=$HELLO_HOST/" .env
    fi

    read -p "Hello service port [8004]: " HELLO_PORT
    if [ ! -z "$HELLO_PORT" ]; then
        sed -i.bak "s/HELLO_SERVICE_PORT=.*/HELLO_SERVICE_PORT=$HELLO_PORT/" .env
    fi

    # LLM Proxy
    read -p "LLM proxy host [localhost]: " LLM_HOST
    if [ ! -z "$LLM_HOST" ]; then
        sed -i.bak "s/LLM_PROXY_HOST=.*/LLM_PROXY_HOST=$LLM_HOST/" .env
    fi

    read -p "LLM proxy port [8012]: " LLM_PORT
    if [ ! -z "$LLM_PORT" ]; then
        sed -i.bak "s/LLM_PROXY_PORT=.*/LLM_PROXY_PORT=$LLM_PORT/" .env
    fi

    # Clean up backup files
    rm -f .env.bak

    echo
    echo "✅ Configuration complete!"
else
    echo "✅ Using default configuration values."
fi

echo
echo "Your environment is now configured!"
echo "You can edit the .env file manually at any time."
echo
echo "To start the services with your configuration, run:"
echo "  make setup"
echo