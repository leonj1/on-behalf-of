#!/usr/bin/env python3
"""
Test token exchange capability for service-a client.
This script validates that service-a can perform token exchange before updating the service.
"""
import requests
import sys
import json
import os

def get_service_token(keycloak_url, client_id, client_secret):
    """Get a service account token for service-a"""
    token_url = f"{keycloak_url}/realms/master/protocol/openid-connect/token"
    
    data = {
        'grant_type': 'client_credentials',
        'client_id': client_id,
        'client_secret': client_secret
    }
    
    try:
        response = requests.post(token_url, data=data)
        if response.status_code == 200:
            return response.json()['access_token']
        else:
            print(f"Failed to get service token: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"Error getting service token: {e}")
        return None

def test_token_exchange(keycloak_url, client_id, client_secret, subject_token, target_audience):
    """Test if token exchange works"""
    token_url = f"{keycloak_url}/realms/master/protocol/openid-connect/token"
    
    exchange_data = {
        'grant_type': 'urn:ietf:params:oauth:grant-type:token-exchange',
        'subject_token': subject_token,
        'subject_token_type': 'urn:ietf:params:oauth:token-type:access_token',
        'requested_token_type': 'urn:ietf:params:oauth:token-type:access_token',
        'audience': target_audience,
        'client_id': client_id,
        'client_secret': client_secret
    }
    
    try:
        print(f"Testing token exchange from {client_id} to audience {target_audience}...")
        response = requests.post(token_url, data=exchange_data)
        
        if response.status_code == 200:
            print("✓ Token exchange successful!")
            token_data = response.json()
            # You could decode and print the token details here
            return True
        else:
            print(f"✗ Token exchange failed: {response.status_code}")
            print(f"  Error: {response.text}")
            return False
    except Exception as e:
        print(f"✗ Error during token exchange: {e}")
        return False

def main():
    # Configuration
    keycloak_url = os.getenv('KEYCLOAK_URL', 'http://localhost:8080')
    client_id = 'service-a'
    client_secret = os.getenv('SERVICE_A_CLIENT_SECRET')
    
    if not client_secret:
        print("✗ SERVICE_A_CLIENT_SECRET not set")
        sys.exit(1)
    
    print(f"Testing token exchange for {client_id}...")
    print(f"Keycloak URL: {keycloak_url}")
    print("")
    
    # First, get a service account token to use as subject token
    print("1. Getting service account token...")
    service_token = get_service_token(keycloak_url, client_id, client_secret)
    if not service_token:
        print("✗ Failed to get service account token")
        print("  Check that service accounts are enabled for service-a")
        sys.exit(1)
    print("✓ Got service account token")
    print("")
    
    # Test token exchange to banking-service audience
    print("2. Testing token exchange to banking-service audience...")
    success = test_token_exchange(
        keycloak_url, 
        client_id, 
        client_secret, 
        service_token, 
        'banking-service'
    )
    
    if not success:
        print("")
        print("Token exchange is not working. Possible issues:")
        print("1. Token exchange may not be enabled for service-a client")
        print("2. Authorization policies may not be configured correctly")
        print("3. The target audience (banking-service) may not exist")
        print("4. Keycloak version may require different configuration")
        sys.exit(1)
    
    print("")
    print("✓ Token exchange validation successful!")
    print("  service-a can exchange tokens for banking-service audience")
    sys.exit(0)

if __name__ == '__main__':
    main()