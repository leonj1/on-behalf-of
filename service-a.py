from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from jose import jwt, JWTError
import httpx
from typing import Optional
import secrets
import os

app = FastAPI(
    title="Service A",
    description="Service that acts on behalf of users to call other services",
    version="1.0.0"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:3001", "http://localhost:3005", "http://10.1.1.74:3005", "http://100.68.45.127:3005"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security scheme
security = HTTPBearer()

# Configuration
CONSENT_STORE_URL = "http://consent-store:8001"
BANKING_SERVICE_URL = "http://banking-service:8012"
SERVICE_NAME = "service-a"

# Keycloak configuration
KEYCLOAK_URL = os.getenv("KEYCLOAK_URL", "http://keycloak:8080")
KEYCLOAK_REALM = os.getenv("KEYCLOAK_REALM", "master")
CLIENT_ID = os.getenv("CLIENT_ID", "service-a")
CLIENT_SECRET = os.getenv("CLIENT_SECRET", "")  # Should be set via environment variable

async def get_user_info(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Extract user info from JWT token"""
    token = credentials.credentials
    
    try:
        # Decode without verification for development
        # In production, properly verify the token
        payload = jwt.get_unverified_claims(token)
        
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token: no user ID"
            )
        
        return {
            "user_id": user_id,
            "token": token,
            "username": payload.get("preferred_username", user_id)
        }
        
    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {str(e)}"
        )

async def exchange_token_for_audience(user_token: str, target_audience: str) -> Optional[str]:
    """
    Exchange user's token for a new token with different audience using OAuth2 Token Exchange.
    
    This implements RFC 8693 - OAuth 2.0 Token Exchange
    """
    async with httpx.AsyncClient() as client:
        try:
            # Get service-a's client credentials first
            # In production, this should be cached and refreshed as needed
            token_endpoint = f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/token"
            
            # Token exchange request
            exchange_data = {
                "grant_type": "urn:ietf:params:oauth:grant-type:token-exchange",
                "subject_token": user_token,
                "subject_token_type": "urn:ietf:params:oauth:token-type:access_token",
                "requested_token_type": "urn:ietf:params:oauth:token-type:access_token",
                "audience": target_audience,
                "client_id": CLIENT_ID,
                "client_secret": CLIENT_SECRET or "dummy-secret"  # Will need actual secret
            }
            
            print(f"Attempting token exchange for audience: {target_audience}")
            
            response = await client.post(
                token_endpoint,
                data=exchange_data,
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
            
            if response.status_code == 200:
                token_data = response.json()
                print("Token exchange successful")
                return token_data.get("access_token")
            else:
                print(f"Token exchange failed: {response.status_code} - {response.text}")
                
                # Fallback: Try to get a service account token with act claim
                # This is an alternative approach if token exchange is not enabled
                service_token_data = {
                    "grant_type": "client_credentials",
                    "client_id": CLIENT_ID,
                    "client_secret": CLIENT_SECRET or "dummy-secret",
                    "scope": "openid"
                }
                
                response = await client.post(
                    token_endpoint,
                    data=service_token_data,
                    headers={"Content-Type": "application/x-www-form-urlencoded"}
                )
                
                if response.status_code == 200:
                    # For now, return None to indicate we couldn't exchange
                    # In a real implementation, we might use the service token
                    print("Got service token, but need user context")
                    return None
                
                return None
                
        except Exception as e:
            print(f"Error during token exchange: {e}")
            return None

async def check_consent(user_id: str, capability: str) -> bool:
    """Check if user has granted consent for service-a to use banking-service capability"""
    async with httpx.AsyncClient() as client:
        try:
            # Use POST request with JSON body
            consent_data = {
                "user_id": user_id,
                "requesting_app_name": SERVICE_NAME,
                "destination_app_name": "service-b",
                "capabilities": [capability]
            }
            
            print(f"Checking consent with data: {consent_data}")
            
            response = await client.post(
                f"{CONSENT_STORE_URL}/consent/check",
                json=consent_data
            )
            
            print(f"Consent check response: {response.status_code} - {response.text}")
            
            if response.status_code == 200:
                result = response.json()
                return result.get("all_granted", False)
            else:
                print(f"Consent check failed: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            print(f"Error checking consent: {e}")
            return False

@app.get("/")
def root():
    return {"message": "Service A", "version": "1.0.0"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}

@app.post("/withdraw")
async def withdraw(user_info: dict = Depends(get_user_info)):
    """
    Withdraw money on behalf of the user.
    First checks consent, then calls banking service if consent is granted.
    """
    user_id = user_info["user_id"]
    token = user_info["token"]
    username = user_info["username"]
    
    # Check if user has granted consent for withdraw capability
    has_consent = await check_consent(user_id, "withdraw")
    
    if not has_consent:
        # Generate a random state token for CSRF protection
        state_token = secrets.token_urlsafe(32)
        
        # Return structured consent-required response
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error_code": "consent_required",
                "destination_service": "service-b",
                "destination_service_name": "Banking Service",
                "operations": ["withdraw"],
                "operation_descriptions": {
                    "withdraw": "Allow withdrawal of funds from your bank account"
                },
                "client_id": "nextjs-app",
                "consent_ui_url": "http://100.68.45.127:8012/consent",
                "consent_params": {
                    "requesting_service": "service-a",
                    "requesting_service_name": "Service A",
                    "destination_service": "service-b",
                    "operations": "withdraw",  # This will be passed as-is in URL
                    "redirect_uri": "http://10.1.1.74:3005/consent-callback",
                    "state": state_token
                }
            }
        )
    
    # Exchange token for one with banking-service audience
    exchanged_token = await exchange_token_for_audience(token, "banking-service")
    
    if not exchanged_token:
        # If token exchange fails, try using the original token
        # Some setups might accept the original token
        print("Token exchange failed, attempting with original token")
        exchanged_token = token
    
    # Call banking service with exchanged token
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                f"{BANKING_SERVICE_URL}/withdraw",
                headers={"Authorization": f"Bearer {exchanged_token}"}
            )
            
            if response.status_code == 200:
                return {
                    "message": f"Successfully processed withdrawal for user {username}",
                    "banking_response": response.json()
                }
            elif response.status_code == 403:
                error_detail = "Banking service rejected the request"
                try:
                    error_data = response.json()
                    if "detail" in error_data:
                        error_detail = error_data["detail"]
                except:
                    pass
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=error_detail
                )
            else:
                raise HTTPException(
                    status_code=response.status_code,
                    detail=f"Banking service error: {response.text}"
                )
                
        except httpx.RequestError as e:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Cannot reach banking service: {str(e)}"
            )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8004)