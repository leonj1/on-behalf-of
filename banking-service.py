from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from jose import jwt, JWTError
import httpx
from typing import Optional

app = FastAPI(
    title="Banking Service",
    description="Protected banking service with JWT validation",
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
KEYCLOAK_URL = "http://keycloak:8080"
REALM = "master"
SERVICE_AUDIENCE = "banking-service"

async def get_keycloak_public_key():
    """Fetch Keycloak public key for JWT validation"""
    try:
        async with httpx.AsyncClient() as client:
            # Get realm info
            response = await client.get(f"{KEYCLOAK_URL}/realms/{REALM}")
            response.raise_for_status()
            realm_info = response.json()
            
            # Get certificates
            certs_response = await client.get(f"{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/certs")
            certs_response.raise_for_status()
            
            return certs_response.json()
    except Exception as e:
        print(f"Error fetching Keycloak public key: {e}")
        return None

async def validate_jwt(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Validate JWT token and check audience"""
    token = credentials.credentials
    
    try:
        # For development, we'll decode without verification first to check claims
        # In production, you should properly verify with the public key
        unverified_payload = jwt.get_unverified_claims(token)
        
        # Check audience
        audience = unverified_payload.get("aud", [])
        if isinstance(audience, str):
            audience = [audience]
        
        if SERVICE_AUDIENCE not in audience:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Invalid audience. Expected '{SERVICE_AUDIENCE}'"
            )
        
        # In production, verify the token with proper public key
        # For now, we'll trust the token if audience is correct
        return unverified_payload
        
    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {str(e)}"
        )

@app.get("/")
def root():
    return {"message": "Banking Service", "version": "1.0.0"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}

@app.post("/withdraw")
async def withdraw(user_info: dict = Depends(validate_jwt)):
    """Withdraw money from account - requires valid JWT with correct audience"""
    return {
        "message": "Withdrew $1000 from account",
        "user": user_info.get("preferred_username", user_info.get("sub", "unknown"))
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8012)