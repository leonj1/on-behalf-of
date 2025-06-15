# Implementation Plan for On-Behalf-Of Demo

## Overview
This project demonstrates a microservices architecture with OAuth2/OIDC authentication via Keycloak, consent management, and service-to-service authorization using the "on-behalf-of" pattern.

## Architecture Components
- **Keycloak**: Identity and Access Management
- **Consent Store**: Manages application capabilities and user consent
- **Service A**: Acts on behalf of users to call other services
- **Banking Service**: Protected service requiring specific audience
- **Hello Service**: Simple unprotected service
- **NextJS Frontend**: User interface for authentication and service interaction

## Detailed Implementation Steps

### Phase 1: Infrastructure Setup (Steps 1-3) ✅ COMPLETED

#### 1.1 Create Docker Compose File ✅
- Create `docker-compose.yml` with Keycloak service
- Use `quay.io/keycloak/keycloak:latest` image
- Configure environment variables:
  - `KEYCLOAK_ADMIN=admin`
  - `KEYCLOAK_ADMIN_PASSWORD=admin`
- Map port 8080:8080
- Add health check for readiness
- Create network `demo-network` for service communication

#### 1.2 Create Makefile ✅
- **start**: `docker-compose up -d`
- **stop**: `docker-compose down`
- **restart**: `make stop && make start`
- **logs**: `docker-compose logs -f`
- **ps**: `docker-compose ps`

#### 1.3 Validate Keycloak ✅
- Wait for health check to pass
- Verify admin console accessible at http://localhost:8080

### Phase 2: Keycloak Configuration (Steps 4-6, 14) ✅ COMPLETED

#### 2.1 Create Client Registration Script ✅
- Create `create-clientid.py` using `python-keycloak` library
- Accept command-line arguments:
  - `--client-id` (required)
  - `--keycloak-url` (default: http://localhost:8080)
  - `--realm` (default: master)
- Configure client settings:
  - Client Protocol: openid-connect
  - Access Type: confidential
  - Valid Redirect URIs: http://localhost:3000/*
  - Generate client secret

#### 2.2 Create Integration Test Script ✅
- Create `integration-test.sh`:
  - Start Keycloak with `make start`
  - Wait for Keycloak readiness (poll health endpoint)
  - Create realm if needed
  - Run `create-clientid.py` for service-a
  - Run `create-clientid.py` for service-b
  - Verify clients created successfully

#### 2.3 Configure Google Authentication ✅
- Created `configure-google-auth.sh` script for automated setup
- Created `GOOGLE_AUTH_SETUP.md` with detailed instructions
- Added `make configure-google-auth` target
- Script configures:
  - Google Identity Provider in Keycloak
  - OAuth 2.0 Client ID and Secret
  - Redirect URIs for localhost and external IP
  - Trust email and token storage settings

### Phase 3: Core Services Implementation ✅ COMPLETED

#### 3.1 Consent Store Service (Steps 7-10) ✅
**File Structure:**
```
consent-store/
├── Dockerfile
├── requirements.txt
├── consent_store.py
├── database/
│   ├── __init__.py
│   ├── repository.py (interface)
│   └── sqlite_repository.py
├── models/
│   ├── __init__.py
│   └── schemas.py
└── routers/
    ├── __init__.py
    ├── applications.py
    └── consent.py
```

**Database Schema:**
```sql
-- applications table
CREATE TABLE applications (
    id INTEGER PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- capabilities table
CREATE TABLE capabilities (
    id INTEGER PRIMARY KEY,
    application_id INTEGER,
    capability TEXT NOT NULL,
    FOREIGN KEY (application_id) REFERENCES applications(id),
    UNIQUE(application_id, capability)
);

-- user_consents table
CREATE TABLE user_consents (
    id INTEGER PRIMARY KEY,
    user_id TEXT NOT NULL,
    requesting_app_id INTEGER,
    destination_app_id INTEGER,
    capability TEXT NOT NULL,
    granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (requesting_app_id) REFERENCES applications(id),
    FOREIGN KEY (destination_app_id) REFERENCES applications(id),
    UNIQUE(user_id, requesting_app_id, destination_app_id, capability)
);
```

**API Endpoints:**
- `POST /applications` - Register application
- `PUT /applications/{app_id}/capabilities` - Add capability
- `DELETE /applications/{app_id}/capabilities/{capability}` - Remove capability
- `DELETE /applications/{app_id}` - Delete application
- `GET /applications` - List all applications
- `GET /applications/{app_id}/capabilities` - List capabilities
- `GET /consent/check` - Check if user granted consent
- `POST /consent` - Record user consent
- `DELETE /consent/user/{user_id}/capability` - Delete specific consent
- `DELETE /consent/user/{user_id}` - Clear all user consent
- `DELETE /consent/all` - Clear all consent

**Dockerfile:**
- Base image: `python:3.11-slim`
- Install dependencies
- Copy application code
- Expose port 8001
- Run with uvicorn

#### 3.2 Banking Service (Step 12) ✅
**Implementation:**
- Create `banking-service.py` with FastAPI
- JWT validation middleware using `python-jose`
- Validate:
  - Token signature
  - Token expiry
  - Audience claim matches "banking-service"
- `POST /withdraw` endpoint returns success message

#### 3.3 Hello Service (Step 13) ✅
**Implementation:**
- Create `hello.py` with FastAPI
- Simple `GET /hello` endpoint
- No authentication required
- Returns "hi there!"

#### 3.4 Service A (Step 15) ✅
**Implementation:**
- Create `service-a.py` with FastAPI
- `POST /withdraw` endpoint:
  - Extract user ID from JWT
  - Call consent-store to check consent
  - If consent granted, call banking-service with user's token
  - Return appropriate response

### Phase 4: Frontend Applications ✅ COMPLETED

#### 4.1 React Component Library (Step 11) ✅
**Setup:**
- Create React app with Vite
- Install Tailwind CSS
- Create components:
  - `Header` - Navigation with Applications/Users buttons
  - `UserConsent` - List and manage user consents
  - API client for consent-store

#### 4.2 NextJS Application (Step 16) ✅
**Implementation:**
- Create NextJS 14 app with App Router
- Configure NextAuth.js with Keycloak provider
- Protected routes requiring authentication
- Landing page with:
  - Google login via Keycloak
  - Post-login dashboard with action buttons
  - "Say Hello" - calls hello service
  - "Empty Bank Account" - calls service-a (which may call banking-service)

### Phase 5: Integration and Testing ✅ COMPLETED

#### 5.1 Update Docker Compose ✅
- Add all services to docker-compose.yml:
  - consent-store (port 8001)
  - banking-service (port 8012)
  - hello (port 8003)
  - service-a (port 8004)
  - nextjs-app (port 3000)
- Configure service dependencies
- Use shared network for communication

#### 5.2 Environment Configuration ✅
- Create `.env` files for each service
- Configure CORS for frontend-backend communication
- Set service discovery URLs

#### 5.3 Final Testing (Step 17) ✅
- Run `make start`
- Verify all services are running
- Test complete flow:
  1. User logs in with Google
  2. User clicks "Say Hello" - should work
  3. User clicks "Empty Bank Account" - should fail (no consent)
  4. Admin grants consent via consent-store
  5. User clicks "Empty Bank Account" - should succeed

## Implementation Order

1. Infrastructure (docker-compose, Makefile)
2. Keycloak setup and client creation
3. Consent store service with database
4. Simple services (hello, banking)
5. Service A with consent checking
6. Frontend applications
7. Integration testing

## Key Considerations

- **Security**: All JWT validation should verify issuer, audience, and signature
- **Error Handling**: Proper HTTP status codes and error messages
- **Logging**: Structured logging for debugging
- **CORS**: Configure for local development
- **Database**: Use SQLite for simplicity, but design for easy migration
- **Configuration**: Environment variables for all service URLs and secrets