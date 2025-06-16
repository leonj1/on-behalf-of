#!/usr/bin/env python3
"""
Keycloak Login Validation Script
Tests multiple authentication methods to validate admin/admin credentials work correctly
"""

import requests
import json
import sys
from urllib.parse import urlparse

def test_admin_cli_authentication():
    """Test admin authentication via Keycloak admin CLI"""
    print("1. Testing Keycloak Admin CLI Authentication")
    print("-" * 50)
    
    try:
        # Test direct token request to admin CLI
        response = requests.post(
            "https://keycloak-api.joseserver.com/realms/master/protocol/openid-connect/token",
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            data={
                "grant_type": "password",
                "client_id": "admin-cli",
                "username": "admin",
                "password": "admin"
            },
            timeout=10
        )
        
        if response.status_code == 200:
            token_data = response.json()
            print("   ✅ Admin CLI authentication successful")
            print(f"   Token type: {token_data.get('token_type', 'N/A')}")
            print(f"   Expires in: {token_data.get('expires_in', 'N/A')} seconds")
            return True, token_data.get('access_token')
        else:
            print(f"   ❌ Admin CLI authentication failed: {response.status_code}")
            if response.text:
                error_data = response.json() if response.headers.get('content-type', '').startswith('application/json') else {}
                print(f"   Error: {error_data.get('error_description', response.text[:100])}")
            return False, None
            
    except requests.exceptions.RequestException as e:
        print(f"   ❌ Network error: {e}")
        return False, None
    except Exception as e:
        print(f"   ❌ Error: {e}")
        return False, None

def test_nextjs_app_authentication():
    """Test admin authentication via nextjs-app client"""
    print("\n2. Testing NextJS App Client Authentication")
    print("-" * 50)
    
    # Get the current client secret from frontend config
    client_secret = "zKpNd0k5w8gfNftSEQh0ZbH8COTMvkwJ"  # From the updated .env.local
    
    try:
        # Test password grant with nextjs-app client
        response = requests.post(
            "https://keycloak-api.joseserver.com/realms/master/protocol/openid-connect/token",
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            data={
                "grant_type": "password",
                "client_id": "nextjs-app",
                "client_secret": client_secret,
                "username": "admin",
                "password": "admin"
            },
            timeout=10
        )
        
        if response.status_code == 200:
            token_data = response.json()
            print("   ✅ NextJS App client authentication successful")
            print(f"   Token type: {token_data.get('token_type', 'N/A')}")
            print(f"   Expires in: {token_data.get('expires_in', 'N/A')} seconds")
            print(f"   Scope: {token_data.get('scope', 'N/A')}")
            return True, token_data.get('access_token')
        else:
            print(f"   ❌ NextJS App client authentication failed: {response.status_code}")
            if response.text:
                try:
                    error_data = response.json()
                    print(f"   Error: {error_data.get('error_description', error_data.get('error', 'Unknown error'))}")
                except:
                    print(f"   Error response: {response.text[:100]}")
            return False, None
            
    except requests.exceptions.RequestException as e:
        print(f"   ❌ Network error: {e}")
        return False, None
    except Exception as e:
        print(f"   ❌ Error: {e}")
        return False, None

def test_user_info_access(access_token):
    """Test accessing user info with the token"""
    print("\n3. Testing User Info Access")
    print("-" * 50)
    
    if not access_token:
        print("   ⏭️  Skipping - no access token available")
        return False
    
    try:
        response = requests.get(
            "https://keycloak-api.joseserver.com/realms/master/protocol/openid-connect/userinfo",
            headers={"Authorization": f"Bearer {access_token}"},
            timeout=10
        )
        
        if response.status_code == 200:
            user_data = response.json()
            print("   ✅ User info access successful")
            print(f"   Username: {user_data.get('preferred_username', 'N/A')}")
            print(f"   Email verified: {user_data.get('email_verified', 'N/A')}")
            return True
        else:
            print(f"   ❌ User info access failed: {response.status_code}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"   ❌ Network error: {e}")
        return False
    except Exception as e:
        print(f"   ❌ Error: {e}")
        return False

def test_keycloak_admin_api(access_token):
    """Test Keycloak admin API access"""
    print("\n4. Testing Keycloak Admin API Access")
    print("-" * 50)
    
    if not access_token:
        print("   ⏭️  Skipping - no access token available")
        return False
    
    try:
        # Try to list realms (admin operation)
        response = requests.get(
            "https://keycloak-api.joseserver.com/admin/realms",
            headers={"Authorization": f"Bearer {access_token}"},
            timeout=10
        )
        
        if response.status_code == 200:
            realms = response.json()
            print("   ✅ Admin API access successful")
            print(f"   Can access {len(realms)} realm(s)")
            for realm in realms:
                print(f"     - {realm.get('realm', 'Unknown')}")
            return True
        else:
            print(f"   ❌ Admin API access failed: {response.status_code}")
            if response.status_code == 403:
                print("   Note: User may not have admin privileges")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"   ❌ Network error: {e}")
        return False
    except Exception as e:
        print(f"   ❌ Error: {e}")
        return False

def test_nextauth_signin_flow():
    """Test NextAuth signin flow simulation"""
    print("\n5. Testing NextAuth Signin Flow Simulation")
    print("-" * 50)
    
    try:
        session = requests.Session()
        session.headers.update({
            'User-Agent': 'Mozilla/5.0 (compatible; Keycloak-Validator/1.0)'
        })
        
        # Get CSRF token
        csrf_response = session.get("https://consent.joseserver.com/api/auth/csrf", timeout=10)
        if csrf_response.status_code != 200:
            print(f"   ❌ Failed to get CSRF token: {csrf_response.status_code}")
            return False
            
        csrf_data = csrf_response.json()
        csrf_token = csrf_data.get('csrfToken')
        
        if not csrf_token:
            print("   ❌ No CSRF token in response")
            return False
            
        print(f"   ✅ CSRF token obtained: {csrf_token[:20]}...")
        
        # Test signin redirect
        signin_response = session.post(
            "https://consent.joseserver.com/api/auth/signin/keycloak",
            data={
                "csrfToken": csrf_token,
                "callbackUrl": "https://consent.joseserver.com"
            },
            allow_redirects=False,
            timeout=10
        )
        
        if signin_response.status_code in [302, 303]:
            redirect_url = signin_response.headers.get('Location', '')
            if 'keycloak-api.joseserver.com' in redirect_url:
                print("   ✅ NextAuth signin redirect working correctly")
                print(f"   Redirects to: {urlparse(redirect_url).netloc}")
                
                # Check if PKCE is in use
                if 'code_challenge' in redirect_url:
                    print("   ✅ PKCE is enabled in OAuth flow")
                else:
                    print("   ⚠️  PKCE not detected in OAuth flow")
                    
                return True
            else:
                print(f"   ❌ Redirect to wrong URL: {redirect_url}")
                return False
        else:
            print(f"   ❌ Expected redirect, got: {signin_response.status_code}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"   ❌ Network error: {e}")
        return False
    except Exception as e:
        print(f"   ❌ Error: {e}")
        return False

def main():
    """Main validation function"""
    print("=" * 60)
    print("KEYCLOAK ADMIN LOGIN VALIDATION")
    print("=" * 60)
    print("Testing admin/admin credentials across multiple authentication methods\n")
    
    results = []
    access_token = None
    
    # Test 1: Admin CLI
    success, token = test_admin_cli_authentication()
    results.append(("Admin CLI Authentication", success))
    if success and not access_token:
        access_token = token
    
    # Test 2: NextJS App Client
    success, token = test_nextjs_app_authentication()
    results.append(("NextJS App Client Authentication", success))
    if success and not access_token:
        access_token = token
    
    # Test 3: User Info Access
    success = test_user_info_access(access_token)
    results.append(("User Info Access", success))
    
    # Test 4: Admin API Access
    success = test_keycloak_admin_api(access_token)
    results.append(("Admin API Access", success))
    
    # Test 5: NextAuth Flow
    success = test_nextauth_signin_flow()
    results.append(("NextAuth Signin Flow", success))
    
    # Summary
    print("\n" + "=" * 60)
    print("VALIDATION SUMMARY")
    print("=" * 60)
    
    all_passed = True
    for test_name, passed in results:
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{status:<8} {test_name}")
        if not passed:
            all_passed = False
    
    print("\n" + "-" * 60)
    if all_passed:
        print("🎉 ALL TESTS PASSED - admin/admin credentials are working correctly!")
        print("   Users should be able to log in successfully via the frontend.")
    else:
        print("⚠️  SOME TESTS FAILED - There may be authentication issues.")
        print("   Please check the failed tests and fix any configuration problems.")
    
    print("\nCredentials tested: admin / admin")
    print("Frontend URL: https://consent.joseserver.com")
    print("Keycloak URL: https://keycloak-api.joseserver.com")
    
    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())