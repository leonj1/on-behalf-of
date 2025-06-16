# Configuration Guide

This document provides detailed instructions for configuring the application for different environments.

## Overview

All hardcoded IP addresses, localhost references, and port numbers have been removed from the codebase and replaced with environment variables. This makes the application fully portable and deployable to any environment.

## Quick Start

### Option 1: Interactive Setup (Recommended)
```bash
./setup-env.sh
```

### Option 2: Manual Setup
```bash
cp .env.example .env
# Edit .env file with your specific values
```

### Option 3: Use Defaults
The application will work with default values if no .env file is present.

## Environment Variables

### Core Services

| Variable | Default | Description |
|----------|---------|-------------|
| `FRONTEND_PORT` | `3005` | Port for the frontend application |
| `BANKING_SERVICE_HOST` | `100.68.45.127` | Host for banking service |
| `BANKING_SERVICE_PORT` | `8012` | Port for banking service |
| `SERVICE_A_HOST` | `localhost` | Host for service A (main API) |
| `SERVICE_A_PORT` | `8004` | Port for service A |
| `CONSENT_STORE_HOST` | `localhost` | Host for consent store |
| `CONSENT_STORE_PORT` | `8001` | Port for consent store |
| `HELLO_SERVICE_HOST` | `localhost` | Host for hello service |
| `HELLO_SERVICE_PORT` | `8003` | Port for hello service |

### Keycloak Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `KEYCLOAK_HOST` | `100.68.45.127` | Host for Keycloak server |
| `KEYCLOAK_PORT` | `8080` | Port for Keycloak server |
| `KEYCLOAK_REALM` | `master` | Keycloak realm name |
| `KEYCLOAK_INTERNAL_URL` | `http://keycloak:8080` | Internal Keycloak URL for services |

### External URLs (for cross-service communication)

| Variable | Default | Description |
|----------|---------|-------------|
| `EXTERNAL_IP` | `100.68.45.127` | External IP for the host |
| `FRONTEND_EXTERNAL_IP` | `10.1.1.74` | External IP for frontend access |
| `FRONTEND_EXTERNAL_URL` | Auto-generated | Full external URL for frontend |
| `BANKING_SERVICE_EXTERNAL_URL` | Auto-generated | External URL for banking service |
| `CONSENT_STORE_INTERNAL_URL` | `http://consent-store:8001` | Internal URL for consent store |

### Frontend Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `VITE_API_BASE_URL` | `http://localhost:8004` | Base URL for API calls |
| `VITE_SERVICE_A_URL` | `http://localhost:8004` | Service A URL |
| `VITE_BANKING_SERVICE_URL` | `http://100.68.45.127:8012` | Banking service URL |
| `VITE_CONSENT_STORE_URL` | `http://localhost:8001` | Consent store URL |
| `VITE_HELLO_SERVICE_URL` | `http://localhost:8003` | Hello service URL |

## Deployment Examples

### Local Development
```bash
# Use defaults - no .env file needed
make setup
```

### Different Host
```bash
# Copy and edit .env
cp .env.example .env

# Edit these variables in .env:
EXTERNAL_IP=192.168.1.100
FRONTEND_EXTERNAL_IP=192.168.1.100
KEYCLOAK_HOST=192.168.1.100
BANKING_SERVICE_HOST=192.168.1.100

make setup
```

### Custom Ports
```bash
# Edit .env for different ports:
FRONTEND_PORT=4000
SERVICE_A_PORT=9001
CONSENT_STORE_PORT=9002
HELLO_SERVICE_PORT=9003
BANKING_SERVICE_PORT=9004
KEYCLOAK_PORT=9080

make setup
```

### Production Deployment
```bash
# Set production values in .env:
EXTERNAL_IP=your-production-ip
FRONTEND_EXTERNAL_IP=your-frontend-ip
KEYCLOAK_HOST=your-keycloak-host
# ... other production values

make setup
```

## Configuration Files

### Backend Services
- `config.py` - Centralized configuration for all Python services
- Automatically loads from `.env` file using python-dotenv
- Provides reasonable defaults for all values

### Frontend
- `frontend/src/lib/config.ts` - Frontend configuration module
- Uses Vite environment variables (`VITE_*` prefix)
- Includes helper functions for building URLs

### Infrastructure
- `docker-compose.yml` - Uses environment variables with fallback defaults
- `Makefile` - Already uses environment variables throughout

## Validation

After configuration, verify your setup:

1. **Check service health:**
   ```bash
   make show-secrets  # Shows all service URLs
   ```

2. **Test connectivity:**
   ```bash
   # Test each service individually
   curl http://localhost:${CONSENT_STORE_PORT:-8001}/health
   curl http://localhost:${HELLO_SERVICE_PORT:-8003}/health
   curl http://localhost:${SERVICE_A_PORT:-8004}/
   ```

3. **View all running services:**
   ```bash
   make ps
   ```

## Troubleshooting

### Port Conflicts
If you get port binding errors:
1. Check what's using the ports: `lsof -i :PORT`
2. Either stop the conflicting service or change the port in `.env`

### Service Communication Issues
1. Verify the internal URLs are correct for your deployment
2. Check that `CONSENT_STORE_INTERNAL_URL` and `KEYCLOAK_INTERNAL_URL` match your actual service locations
3. For Docker deployments, use service names (e.g., `http://consent-store:8001`)

### Frontend API Calls Failing
1. Ensure `VITE_*` variables are set correctly
2. Restart the frontend after changing environment variables
3. Check browser console for CORS issues

## Advanced Configuration

### Using Custom Config Files
You can create environment-specific files:
```bash
# Development
cp .env.example .env.development

# Production  
cp .env.example .env.production

# Load specific environment
export $(cat .env.development | xargs) && make setup
```

### Override Specific Services
You can mix and match local and remote services:
```bash
# Use local services but remote banking service
BANKING_SERVICE_HOST=remote-banking-server.com
BANKING_SERVICE_PORT=443
BANKING_SERVICE_EXTERNAL_URL=https://remote-banking-server.com
```