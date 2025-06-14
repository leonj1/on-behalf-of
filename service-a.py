from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from jose import jwt, JWTError
import httpx
from typing import Optional

app = FastAPI(
    title="Service A",
    description="Service that acts on behalf of users to call other services",
    version="1.0.0"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:3001"],
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

async def check_consent(user_id: str, capability: str) -> bool:
    """Check if user has granted consent for service-a to use banking-service capability"""
    async with httpx.AsyncClient() as client:
        try:
            params = {
                "user_id": user_id,
                "requesting_app_name": SERVICE_NAME,
                "destination_app_name": "service-b",  # banking service is registered as service-b
                "capabilities": capability
            }
            
            response = await client.get(
                f"{CONSENT_STORE_URL}/consent/check",
                params=params
            )
            
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
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"User {username} has not granted consent for service-a to perform withdraw operations"
        )
    
    # Call banking service with user's token
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                f"{BANKING_SERVICE_URL}/withdraw",
                headers={"Authorization": f"Bearer {token}"}
            )
            
            if response.status_code == 200:
                return {
                    "message": f"Successfully processed withdrawal for user {username}",
                    "banking_response": response.json()
                }
            elif response.status_code == 403:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Banking service rejected the request - invalid audience in token"
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