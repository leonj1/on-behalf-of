# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an OAuth2 "on-behalf-of" demonstration project showcasing microservices authorization patterns with explicit consent management. The system demonstrates how services can act on behalf of users to access other protected services after obtaining user consent.

## Architecture

### Service Communication Flow
```
Frontend (Next.js) → Service A → Banking Service
                  ↓            ↓
              Consent Store ← ─┘
                  ↑
              Keycloak (Auth)
```

### Core Services
- **Frontend** (Port 3005): Next.js 15 with NextAuth, TypeScript, Tailwind/Pico CSS
- **Service A** (Port 8004): FastAPI orchestrator that acts on-behalf-of users
- **Banking Service** (Port 8012): Protected FastAPI service requiring JWT audience validation
- **Consent Store** (Port 8001): FastAPI service managing user consent with SQLite
- **Hello Service** (Port 8003): Simple unprotected FastAPI service
- **Keycloak** (Port 8080): OAuth2/OIDC identity provider

## Development Commands

### Primary Workflow
```bash
# Complete setup (recommended)
make stop               # Stop any existing services
./setup-env.sh         # Configure environment (optional but recommended)
make setup             # Start all services and configure

# Daily development
make logs              # View all service logs
make show-secrets      # Display client credentials
make ps               # Show container status
make stop             # Stop all services
```

### Testing and Validation
```bash
# Test the consent flow
./test-consent-flow.sh

# Grant test consent for quick testing
./grant-test-consent.sh

# Validate services are healthy
curl http://localhost:8001/health  # Consent Store
curl http://localhost:8003/health  # Hello Service
```

### Configuration Management
```bash
# Run interactive setup
./setup-env.sh

# Manual configuration
cp .env.example .env
# Edit .env with your values
```

## Key Implementation Patterns

### JWT Audience Validation
All protected services validate JWT audience claims. Banking Service accepts tokens with audiences: `banking-service`, `service-a`, `account`, `nextjs-app`.

### Consent Flow
1. Service A checks consent before calling protected services
2. If no consent exists, returns 403 with `consent_required` error
3. Frontend redirects to consent UI (Banking Service)
4. User grants/denies consent
5. Consent is stored persistently in SQLite

### Service-to-Service Communication
- Internal communication uses Docker service names (e.g., `http://consent-store:8001`)
- External URLs configured via environment variables for frontend access
- All services use CORS with specific allowed origins

## Configuration Architecture

### Environment Variables
- All hardcoded IPs/ports removed in favor of environment variables
- Configuration centralized in `config.py` for Python services
- Frontend uses `frontend/src/lib/config.ts` for configuration
- Docker Compose uses environment substitution with defaults

### Key Configuration Files
- `.env` - Main environment configuration (created from .env.example)
- `frontend/.env.local` - Frontend-specific configuration
- `config.py` - Python services configuration loader
- `setup-env.sh` - Interactive configuration script

## Testing Workflow

1. Start services: `make setup`
2. Login at http://localhost:3005 (admin/admin or create user)
3. Test unprotected service: "Say Hello" button
4. Test protected service: "Empty Bank Account" (will fail initially)
5. Grant consent through the consent UI
6. Retry protected service (should succeed)
7. Manage consents through "Manage Consents" UI

## Important Implementation Details

### Python Services
- Use explicit imports, not wildcard imports (`from config import *`)
- FastAPI with Uvicorn for all backend services
- python-jose for JWT validation
- SQLite for consent persistence

### Frontend
- Next.js 15 with App Router
- NextAuth for authentication
- Service-specific external URLs configured via environment
- Dark theme with Pico CSS framework

### Security Considerations
- CSRF protection in consent flow using state tokens
- JWT validation on all protected endpoints
- Audience claim validation for service authorization
- Client secrets auto-synchronized from Keycloak

## Common Tasks

### Add New Service
1. Define service in docker-compose.yml
2. Add configuration variables to .env.example
3. Update config.py with new service configuration
4. Add service URL to frontend config if needed
5. Update setup-env.sh for interactive configuration

### Debug Authentication Issues
1. Check JWT audience claims match service expectations
2. Verify Keycloak client configuration
3. Ensure client secrets are synchronized
4. Check service logs: `docker logs <service-name>`

### Reset Everything
```bash
make stop
make clean-clients
docker volume prune -f
make setup
```