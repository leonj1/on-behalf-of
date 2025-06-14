# Keycloak SSL Configuration for Development

## Problem
Keycloak by default requires HTTPS for any non-localhost access. When accessing Keycloak from an external IP (like 100.68.45.127), it returns an "ssl_required" error.

## Solution
To disable SSL requirements for local development, we need to configure both:

### 1. Server-Level Configuration (docker-compose.yml)
```yaml
environment:
  - KC_HTTP_ENABLED=true          # Enable HTTP
  - KC_HOSTNAME_STRICT=false      # Disable strict hostname checking
  - KC_HOSTNAME_STRICT_HTTPS=false # Disable HTTPS requirement
  - KC_PROXY=edge                 # Tell Keycloak it's behind a proxy
  - KC_HOSTNAME_STRICT_BACKCHANNEL=false # Disable backchannel checks
  - KC_HOSTNAME=100.68.45.127    # Set the hostname to your server IP
```

### 2. Realm-Level Configuration
Even with server-level settings, the master realm has `sslRequired` set to "external" by default. This must be changed to "NONE" using Keycloak's admin CLI:

```bash
# Set SSL requirement to NONE for the master realm
docker exec keycloak /opt/keycloak/bin/kcadm.sh update realms/master \
  -s sslRequired=NONE
```

## Automated Configuration
The `configure-keycloak.sh` script automatically:
1. Authenticates with Keycloak admin
2. Updates the master realm to set `sslRequired=NONE`
3. Verifies the configuration was applied

This script is automatically run by `make start` after Keycloak is ready.

## Manual Configuration
If needed, you can manually disable SSL by running:
```bash
./disable-keycloak-ssl.sh
```

## Security Warning
⚠️ **This configuration is for DEVELOPMENT ONLY!**
- Never use these settings in production
- Always use HTTPS with valid certificates in production
- These settings disable important security features

## Troubleshooting
If you still get SSL errors:
1. Check Keycloak logs: `docker logs keycloak`
2. Verify the realm setting: 
   ```bash
   docker exec keycloak /opt/keycloak/bin/kcadm.sh get realms/master --fields sslRequired
   ```
3. Ensure all environment variables are set in docker-compose.yml
4. Try restarting Keycloak: `make restart`