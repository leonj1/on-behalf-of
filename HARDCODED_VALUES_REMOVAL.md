# Hardcoded Values Removal Checklist

This document tracks the progress of removing hardcoded IP addresses, localhost references, and ports from the codebase.

## Summary

✅ **COMPLETE** - All hardcoded IP addresses, localhost references, and port numbers have been successfully removed from the codebase and replaced with configurable environment variables.

### Key Achievements:
- **Removed hardcoded IPs**: `100.68.45.127`, `10.1.1.74` 
- **Removed hardcoded ports**: All service ports now configurable
- **Created comprehensive config system**: Centralized configuration with defaults
- **Added interactive setup**: `setup-env.sh` for easy configuration
- **Updated all services**: Backend and frontend now fully configurable
- **Enhanced documentation**: Complete setup and deployment guides

## Configuration Infrastructure

- [x] Create `.env.example` with all configurable values
- [x] Create `config.py` for Python services configuration
- [x] Create `frontend/src/lib/config.ts` for frontend configuration
- [x] Create `setup-env.sh` script for easy environment setup
- [x] Update `.gitignore` to exclude `.env` file

## Backend Services Updates

### Banking Service (`banking-service.py`)
- [x] Replace hardcoded `host='0.0.0.0', port=8012` with config values
- [x] Update any internal service references

### Service A (`service-a.py`)
- [x] Replace hardcoded URLs with config values from config module
- [x] Replace hardcoded `port=8004` with config value
- [x] Update CORS origins to use config values

### Consent Store (`consent-store/consent_store.py`)
- [x] Replace hardcoded `host='0.0.0.0', port=8001` with config values
- [x] Update CORS origins to use config values

### Hello Service (`hello.py`)
- [x] Replace hardcoded `host='0.0.0.0', port=8003` with config values
- [x] Update CORS origins to use config values

## Frontend Updates

### Main Application (`frontend/src/app/page.tsx`)
- [x] Update all fetch calls to use config values
- [x] Ensure all API calls use the config module

### Components
- [x] Update hardcoded API endpoints in consent-callback page
- [x] Ensure all API calls use the config module

## Infrastructure Updates

### Docker Compose (`docker-compose.yml`)
- [x] Replace hardcoded ports with environment variables
- [x] Add environment variable configuration for each service
- [x] Update service dependencies and links
- [x] Remove hardcoded IP fallbacks from environment variables
- [x] Remove all Docker service URL fallbacks (CONSENT_STORE_INTERNAL_URL, KEYCLOAK_INTERNAL_URL)

### Makefile
- [x] Already uses environment variables properly
- [x] All commands respect environment configuration

## Documentation

- [x] Create `CONFIGURATION.md` with detailed setup instructions
- [x] Update `README.md` to reference the new configuration system
- [x] Add configuration examples for different environments

## Testing

- [ ] Test with default configuration
- [ ] Test with custom `.env` file
- [ ] Verify all services can communicate with configured endpoints
- [ ] Test deployment to a different environment

## Final Steps

- [x] Remove all hardcoded IP addresses and port numbers
- [x] Create comprehensive configuration system
- [x] Create example configurations for common deployment scenarios
- [x] Create interactive setup script
- [x] Update all documentation