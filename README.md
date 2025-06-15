# On-Behalf-Of OAuth2 Demo

This project demonstrates the OAuth2 "on-behalf-of" authorization pattern combined with a consent management system. It showcases how services can act on behalf of users to access other protected services, but only after explicit user consent has been granted.

## Purpose

The demo illustrates a real-world scenario where:
- **Service A** needs to call **Banking Service** on behalf of a user
- Users must explicitly grant consent for Service A to perform specific actions (like withdrawals)
- All services are protected by JWT tokens with proper audience validation
- A consent store manages and persists user authorization decisions

This pattern is crucial for:
- Protecting user privacy and control over their data
- Implementing fine-grained permissions between microservices
- Building trust in multi-service architectures
- Complying with data protection regulations

## Architecture

- **Keycloak**: Identity and Access Management (OAuth2/OIDC provider)
- **Consent Store**: Manages application capabilities and user consent decisions
- **Service A**: Acts on behalf of users to call other services
- **Banking Service**: Protected service requiring specific JWT audience claims
- **Hello Service**: Simple unprotected service for comparison
- **NextJS Frontend**: User interface with Pico CSS dark theme for authentication and service interaction

## Features

- OAuth2/OIDC authentication via Keycloak
- Service-to-service authorization with JWT validation
- Explicit consent management system with UI
- Beautiful dark-themed UI with gradient buttons
- User-friendly consent management interface
- Support for both local and external IP access
- Optional Google authentication integration

## Getting Started

### Prerequisites

- Docker and Docker Compose
- Python 3.x
- Node.js 20+
- Make

### Quick Start

1. Clone the repository:
```bash
git clone <repository-url>
cd on-behalf-of-demo
```

2. Stop any existing services and start the full stack:
```bash
make stop all
```

This command will:
- Stop any running containers
- Start all services (Keycloak, microservices, frontend)
- Configure Keycloak clients automatically
- Set up the consent store with applications and capabilities
- Display all client secrets
- Create a test user (username: `testuser`, password: `testpass123`)

3. Access the services:
- **Frontend**: http://localhost:3005 or http://10.1.1.74:3005
- **Keycloak Admin**: http://localhost:8080 (admin/admin)
- **Consent Store API**: http://localhost:8001
- **Banking Service**: http://localhost:8012
- **Hello Service**: http://localhost:8003
- **Service A**: http://localhost:8004

## Testing the Flow

1. Navigate to the frontend at http://localhost:3005
2. Click "Sign in with Keycloak"
3. Login with the test user credentials or admin account
4. Test the "Say Hello" button - this should work immediately (unprotected service)
5. Test the "Empty Bank Account" button - this will fail with a consent error
6. Click "Manage Consents" to access the consent management UI
7. Grant consent for service-a to use service-b's withdraw capability
8. Return to home and retry "Empty Bank Account" - it should now succeed

### Quick Test with Pre-granted Consent

To quickly test the full flow with pre-granted consent:
```bash
./grant-test-consent.sh
```

This grants consent for both admin and testuser to allow service-a to perform withdrawals.

## Useful Commands

```bash
# Start all services
make all

# View logs
make logs

# Show client secrets
make show-secrets

# Stop all services
make stop

# Restart services
make restart

# Configure Google authentication (optional)
make configure-google-auth GOOGLE_CLIENT_ID=your-id GOOGLE_CLIENT_SECRET=your-secret
```

## API Endpoints

### Consent Store
- `POST /applications` - Register an application
- `PUT /applications/{app_id}/capabilities` - Add capability to application
- `GET /consent/check` - Check if user granted consent
- `POST /consent` - Record user consent
- `DELETE /consent/user/{user_id}` - Clear user consents

### Service A
- `POST /withdraw` - Attempt to withdraw money on behalf of user (requires consent)

### Banking Service  
- `POST /withdraw` - Withdraw money (requires JWT with correct audience)

### Hello Service
- `GET /hello` - Simple greeting (no authentication required)

## Development

The project uses:
- FastAPI for microservices
- NextJS with NextAuth for frontend
- Pico CSS for beautiful dark theme UI
- SQLite for consent store persistence
- Docker Compose for orchestration

## Security Considerations

- All JWT tokens are validated for proper audience claims
- Services communicate over Docker network internally
- CORS is configured for specific origins only
- Secrets are automatically synchronized between Keycloak and services
- SSL can be enabled for production deployments

## License

This is a demonstration project for educational purposes.