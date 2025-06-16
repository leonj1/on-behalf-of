#!/usr/bin/env python3
"""
Debug script to test the login redirect flow on https://consent.joseserver.com
This script will:
1. Open the consent page
2. Click the login button
3. Capture the actual redirect URL
4. Report whether it redirects to localhost or the correct external URL
"""

import requests
import re
from urllib.parse import urlparse, parse_qs
import sys

def test_login_redirect():
    print("=" * 60)
    print("DEBUGGING LOGIN REDIRECT")
    print("=" * 60)
    
    # Create a session to maintain cookies
    session = requests.Session()
    session.headers.update({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    })
    
    try:
        # Step 1: Get the initial page
        print("1. Loading initial page: https://consent.joseserver.com")
        response = session.get('https://consent.joseserver.com')
        print(f"   Status: {response.status_code}")
        
        if response.status_code != 200:
            print(f"   ❌ Failed to load initial page: {response.status_code}")
            return False
            
        # Step 2: Get the signin page
        print("\n2. Getting NextAuth signin page")
        signin_response = session.get('https://consent.joseserver.com/api/auth/signin/keycloak')
        print(f"   Status: {signin_response.status_code}")
        
        if signin_response.status_code != 200:
            print(f"   ❌ Failed to load signin page: {signin_response.status_code}")
            return False
        
        # Extract CSRF token from the signin page
        csrf_match = re.search(r'name="csrfToken" value="([^"]+)"', signin_response.text)
        if not csrf_match:
            print("   ❌ Could not find CSRF token in signin page")
            return False
            
        csrf_token = csrf_match.group(1)
        print(f"   ✓ Found CSRF token: {csrf_token[:20]}...")
        
        # Step 3: Submit the signin form (simulate clicking login button)
        print("\n3. Submitting signin form (clicking login button)")
        signin_data = {
            'csrfToken': csrf_token,
            'callbackUrl': 'https://consent.joseserver.com'
        }
        
        # Don't follow redirects automatically so we can capture the redirect URL
        signin_submit = session.post(
            'https://consent.joseserver.com/api/auth/signin/keycloak',
            data=signin_data,
            allow_redirects=False
        )
        
        print(f"   Status: {signin_submit.status_code}")
        
        # Step 4: Analyze the redirect
        if signin_submit.status_code in [302, 301, 303, 307, 308]:
            redirect_url = signin_submit.headers.get('Location', '')
            print(f"   ✓ Got redirect to: {redirect_url}")
            
            # Parse the redirect URL
            parsed_url = urlparse(redirect_url)
            
            print(f"\n4. Analyzing redirect URL:")
            print(f"   Full URL: {redirect_url}")
            print(f"   Scheme: {parsed_url.scheme}")
            print(f"   Host: {parsed_url.netloc}")
            print(f"   Path: {parsed_url.path}")
            
            # Check if it's the expected external URL or localhost
            if 'keycloak-api.joseserver.com' in redirect_url:
                print(f"   ✅ SUCCESS: Redirecting to correct external Keycloak URL")
                print(f"   ✅ This means the fix is working!")
                return True
            elif 'localhost' in redirect_url or '127.0.0.1' in redirect_url:
                print(f"   ❌ PROBLEM: Still redirecting to localhost!")
                print(f"   ❌ Expected: https://keycloak-api.joseserver.com/realms/master/...")
                print(f"   ❌ Got:      {redirect_url}")
                return False
            elif 'consent.joseserver.com' in redirect_url:
                print(f"   ⚠️  UNEXPECTED: Redirecting back to consent app")
                print(f"   ⚠️  This might indicate a configuration error or redirect loop")
                
                # If it's a redirect loop, let's follow one more redirect
                if 'signin' in redirect_url:
                    print(f"   🔄 Following redirect to check for loops...")
                    next_response = session.get(redirect_url, allow_redirects=False)
                    if next_response.status_code in [302, 301, 303, 307, 308]:
                        next_redirect = next_response.headers.get('Location', '')
                        print(f"   🔄 Next redirect: {next_redirect}")
                        if next_redirect == redirect_url:
                            print(f"   ❌ REDIRECT LOOP DETECTED!")
                            return False
                return False
            else:
                print(f"   ❓ UNKNOWN: Unexpected redirect URL")
                return False
        else:
            print(f"   ❌ Expected redirect (302), got {signin_submit.status_code}")
            if signin_submit.text:
                print(f"   Response body: {signin_submit.text[:200]}...")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Network error: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False

def check_environment_config():
    """Check the current frontend environment configuration"""
    print("\n" + "=" * 60)
    print("CHECKING ENVIRONMENT CONFIGURATION")
    print("=" * 60)
    
    try:
        with open('/root/src/on-behalf-of/frontend/.env.local', 'r') as f:
            content = f.read()
            
        # Extract key variables
        keycloak_issuer = None
        keycloak_issuer_public = None
        nextauth_url = None
        
        for line in content.split('\n'):
            if line.startswith('KEYCLOAK_ISSUER_PUBLIC='):
                keycloak_issuer_public = line.split('=', 1)[1]
            elif line.startswith('KEYCLOAK_ISSUER='):
                keycloak_issuer = line.split('=', 1)[1]
            elif line.startswith('NEXTAUTH_URL='):
                nextauth_url = line.split('=', 1)[1]
        
        print("Frontend .env.local configuration:")
        print(f"  NEXTAUTH_URL: {nextauth_url}")
        print(f"  KEYCLOAK_ISSUER: {keycloak_issuer}")
        print(f"  KEYCLOAK_ISSUER_PUBLIC: {keycloak_issuer_public}")
        
        # Validate
        expected_external = "https://keycloak-api.joseserver.com"
        if keycloak_issuer_public and expected_external in keycloak_issuer_public:
            print("  ✅ KEYCLOAK_ISSUER_PUBLIC looks correct")
        else:
            print("  ❌ KEYCLOAK_ISSUER_PUBLIC missing or incorrect")
            
        return keycloak_issuer_public
        
    except Exception as e:
        print(f"❌ Could not read environment config: {e}")
        return None

if __name__ == "__main__":
    print("🔍 Debug script for login redirect issue")
    print("This script will test the actual login flow and report the redirect URL")
    print()
    
    # Check environment configuration first
    expected_url = check_environment_config()
    
    # Test the actual login flow
    success = test_login_redirect()
    
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    
    if success:
        print("✅ LOGIN REDIRECT IS WORKING CORRECTLY")
        print("   Users will be redirected to the external Keycloak URL")
    else:
        print("❌ LOGIN REDIRECT ISSUE CONFIRMED")
        print("   Users are being redirected to localhost or wrong URL")
        print()
        print("🔧 TROUBLESHOOTING STEPS:")
        print("   1. Restart frontend container: docker-compose restart frontend")
        print("   2. Check NextAuth configuration in frontend/src/app/api/auth/[...nextauth]/route.ts")
        print("   3. Verify environment variables are loaded: docker-compose exec frontend printenv | grep KEYCLOAK")
        print("   4. Clear browser cache and try incognito mode")
    
    sys.exit(0 if success else 1)