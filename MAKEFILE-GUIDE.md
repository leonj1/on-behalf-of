# Makefile Commands Guide

## Quick Start
```bash
make         # Runs 'all' target - complete setup with credentials display
make all     # Same as above - complete setup with credentials display
make setup   # Complete setup without showing credentials
```

## Individual Commands

### Service Management
- `make all` - Complete setup with everything configured and credentials displayed (default target)
- `make start` - Start all services and configure Keycloak SSL
- `make stop` - Stop all services
- `make restart` - Stop and start all services
- `make ps` - Show status of all containers
- `make logs` - Follow logs from all services

### Setup Commands
- `make setup-clients` - Create all Keycloak client IDs (service-a, service-b, nextjs-app)
- `make setup-consent-store` - Register applications and capabilities in consent store
- `make setup` - Complete setup (start + setup-clients + setup-consent-store)

### Utility Commands
- `make show-secrets` - Display all client IDs and their secrets
- `make clean-clients` - Remove all clients from Keycloak and clear consent store

## Typical Workflow

1. **First time setup:**
   ```bash
   make setup
   ```

2. **Daily development:**
   ```bash
   make start    # Start services
   make logs     # View logs in another terminal
   make stop     # Stop when done
   ```

3. **Reset everything:**
   ```bash
   make stop
   make clean-clients
   make setup
   ```

4. **Get client credentials:**
   ```bash
   make show-secrets
   ```

## Service URLs
After running `make setup`, services are available at:
- Keycloak: http://100.68.45.127:8080 (admin/admin)
- Consent Store: http://localhost:8001
- Banking Service: http://localhost:8012
- Hello Service: http://localhost:8003
- Service A: http://localhost:8004
- Frontend: http://localhost:3005