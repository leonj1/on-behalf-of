#!/bin/bash

# Get nextjs-app client secret
echo "Getting client secret for nextjs-app..."

# First authenticate as admin
docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
    --server http://localhost:8080 \
    --realm master \
    --user admin \
    --password admin \
    --client admin-cli > /dev/null 2>&1

# Get client UUID
CLIENT_UUID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r master --fields id,clientId | jq -r '.[] | select(.clientId=="nextjs-app") | .id')

if [ -n "$CLIENT_UUID" ]; then
    SECRET=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$CLIENT_UUID/client-secret -r master | jq -r '.value')
    echo "Client Secret: $SECRET"
else
    echo "Client not found"
fi