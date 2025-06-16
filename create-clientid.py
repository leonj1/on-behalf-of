#!/usr/bin/env python3
import argparse
import requests
import json
import time
import sys
import os

def get_admin_token(keycloak_url, username='admin', password='admin'):
    """Get admin access token from Keycloak"""
    token_url = f"{keycloak_url}/realms/master/protocol/openid-connect/token"
    
    data = {
        'client_id': 'admin-cli',
        'username': username,
        'password': password,
        'grant_type': 'password'
    }
    
    try:
        response = requests.post(token_url, data=data)
        response.raise_for_status()
        return response.json()['access_token']
    except requests.exceptions.RequestException as e:
        print(f"Error getting admin token: {e}")
        sys.exit(1)

def create_client(keycloak_url, realm, client_id, token):
    """Create a new client in Keycloak"""
    clients_url = f"{keycloak_url}/admin/realms/{realm}/clients"
    
    headers = {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }
    
    client_data = {
        'clientId': client_id,
        'enabled': True,
        'protocol': 'openid-connect',
        'publicClient': False,
        'clientAuthenticatorType': 'client-secret',
        'redirectUris': ['http://localhost:3000/*', f"http://{os.getenv('FRONTEND_EXTERNAL_IP', '10.1.1.74')}:{os.getenv('FRONTEND_PORT', '3005')}/*"],
        'webOrigins': ['http://localhost:3000', f"http://{os.getenv('FRONTEND_EXTERNAL_IP', '10.1.1.74')}:{os.getenv('FRONTEND_PORT', '3005')}"],
        'standardFlowEnabled': True,
        'directAccessGrantsEnabled': True,
        'serviceAccountsEnabled': True,
        'authorizationServicesEnabled': False,
        'attributes': {
            'use.refresh.tokens': 'true',
            'client.secret.creation.time': str(int(time.time()))
        }
    }
    
    try:
        response = requests.post(clients_url, json=client_data, headers=headers)
        
        if response.status_code == 201:
            print(f"Client '{client_id}' created successfully")
            
            # Get the client to retrieve its internal ID
            search_response = requests.get(
                f"{clients_url}?clientId={client_id}",
                headers=headers
            )
            search_response.raise_for_status()
            clients = search_response.json()
            
            if clients:
                client_uuid = clients[0]['id']
                
                # Get client secret
                secret_url = f"{clients_url}/{client_uuid}/client-secret"
                secret_response = requests.get(secret_url, headers=headers)
                secret_response.raise_for_status()
                
                secret = secret_response.json()['value']
                print(f"Client ID: {client_id}")
                print(f"Client Secret: {secret}")
                
                return True
        elif response.status_code == 409:
            print(f"Client '{client_id}' already exists")
            return True
        else:
            print(f"Error creating client: {response.status_code} - {response.text}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"Error creating client: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description='Create a client in Keycloak')
    parser.add_argument('--client-id', required=True, help='Client ID to create')
    parser.add_argument('--keycloak-url', default=os.getenv('KEYCLOAK_EXTERNAL_URL', 'http://localhost:8080'), 
                        help='Keycloak URL (default: from KEYCLOAK_EXTERNAL_URL env or http://localhost:8080)')
    parser.add_argument('--realm', default='master', 
                        help='Keycloak realm (default: master)')
    parser.add_argument('--admin-username', default='admin',
                        help='Admin username (default: admin)')
    parser.add_argument('--admin-password', default='admin',
                        help='Admin password (default: admin)')
    
    args = parser.parse_args()
    
    print(f"Creating client '{args.client_id}' in realm '{args.realm}'...")
    
    # Get admin token
    token = get_admin_token(args.keycloak_url, args.admin_username, args.admin_password)
    
    # Create client
    success = create_client(args.keycloak_url, args.realm, args.client_id, token)
    
    if success:
        print(f"Successfully processed client '{args.client_id}'")
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == '__main__':
    main()