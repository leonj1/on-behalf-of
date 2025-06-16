from fastapi import FastAPI, HTTPException, Depends, status, Request, Form
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from jose import jwt, JWTError
import httpx
from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel
import os
from config import (
    KEYCLOAK_INTERNAL_URL,
    KEYCLOAK_REALM,
    BANKING_SERVICE_EXTERNAL_URL,
    CONSENT_STORE_INTERNAL_URL,
    BANKING_SERVICE_PORT
)

app = FastAPI(
    title="Banking Service",
    description="Protected banking service with JWT validation",
    version="1.0.0"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for consent.json
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security scheme
security = HTTPBearer()

# Configuration
KEYCLOAK_URL = KEYCLOAK_INTERNAL_URL
REALM = KEYCLOAK_REALM
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
        
        # Check audience - accept both banking-service and service-a audiences
        audience = unverified_payload.get("aud", [])
        if isinstance(audience, str):
            audience = [audience]
        
        # Accept tokens for banking-service OR service-a (when called through service-a)
        # Also accept nextjs-app since frontend tokens have that audience
        accepted_audiences = [SERVICE_AUDIENCE, "service-a", "account", "nextjs-app"]  # Include common audiences
        
        if not any(aud in audience for aud in accepted_audiences):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Invalid audience. Expected one of {accepted_audiences}, got {audience}"
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

@app.get("/consent.json")
def get_consent_info():
    """Public endpoint that describes consent requirements for this service"""
    return {
        "service_id": "service-b",
        "service_name": "Banking Service",
        "consent_ui_url": f"{BANKING_SERVICE_EXTERNAL_URL}/consent",
        "consent_required_endpoints": [
            {
                "method": "POST",
                "path": "/withdraw",
                "description": "Withdraw funds from account",
                "required_capabilities": ["withdraw"],
                "capability_descriptions": {
                    "withdraw": "Allow withdrawal of funds from your bank account"
                }
            },
            {
                "method": "GET",
                "path": "/balance",
                "description": "View account balance",
                "required_capabilities": ["view_balance"],
                "capability_descriptions": {
                    "view_balance": "View your current account balance"
                }
            },
            {
                "method": "POST",
                "path": "/transfer",
                "description": "Transfer funds between accounts",
                "required_capabilities": ["transfer", "view_balance"],
                "capability_descriptions": {
                    "transfer": "Transfer funds to other accounts",
                    "view_balance": "View balance to verify sufficient funds"
                }
            }
        ],
        "all_capabilities": [
            {
                "name": "withdraw",
                "display_name": "Withdraw Funds",
                "description": "Allows services to withdraw funds from your account on your behalf",
                "risk_level": "high"
            },
            {
                "name": "view_balance",
                "display_name": "View Balance",
                "description": "Allows services to check your account balance",
                "risk_level": "low"
            },
            {
                "name": "transfer",
                "display_name": "Transfer Funds",
                "description": "Allows services to transfer funds between accounts",
                "risk_level": "high"
            }
        ],
        "consent_metadata": {
            "version": "1.0",
            "last_updated": datetime.now().isoformat() + "Z",
            "contact_email": "support@banking-service.com"
        }
    }

@app.post("/withdraw")
async def withdraw(user_info: dict = Depends(validate_jwt)):
    """Withdraw money from account - requires valid JWT with correct audience"""
    return {
        "message": "Bank account emptied",
        "user": user_info.get("preferred_username", user_info.get("sub", "unknown"))
    }

# Pydantic models for consent
class ConsentDecision(BaseModel):
    decision: str  # "grant" or "deny"
    requesting_service: str
    operations: List[str]
    state: str

# Consent UI endpoint
@app.get("/consent", response_class=HTMLResponse)
async def consent_ui():
    """Serve the consent UI page"""
    # Get the directory where this script is located
    current_dir = os.path.dirname(os.path.abspath(__file__))
    template_path = os.path.join(current_dir, "banking-service-templates", "consent.html")
    
    # Read the HTML template
    try:
        with open(template_path, 'r') as f:
            html_content = f.read()
        return HTMLResponse(content=html_content)
    except FileNotFoundError:
        # If template not found in expected location, check alternative path
        alt_template_path = "/home/jose/src/on-behalf-of-demo/banking-service-templates/consent.html"
        try:
            with open(alt_template_path, 'r') as f:
                html_content = f.read()
            return HTMLResponse(content=html_content)
        except FileNotFoundError:
            raise HTTPException(status_code=500, detail="Consent template not found")

# Consent decision endpoint
@app.post("/consent/decision")
async def consent_decision(
    decision: ConsentDecision,
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """Process user's consent decision"""
    # Validate the JWT token
    try:
        token = credentials.credentials
        # In production, properly verify the token
        payload = jwt.get_unverified_claims(token)
        user_id = payload.get("sub") or payload.get("email") or payload.get("preferred_username")
        
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid token: no user ID")
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {str(e)}")
    
    # Only process grant decisions (deny just redirects)
    if decision.decision == "grant":
        # Call consent store to save the consent
        async with httpx.AsyncClient() as client:
            try:
                # Prepare consent data
                consent_data = {
                    "user_id": user_id,
                    "requesting_app_name": "service-a",  # Always service-a for this flow
                    "destination_app_name": "service-b",  # This service
                    "capabilities": decision.operations
                }
                
                # Save consent to consent store
                print(f"Saving consent: {consent_data}")
                response = await client.post(
                    f"{CONSENT_STORE_INTERNAL_URL}/consent",
                    json=consent_data
                )
                
                print(f"Consent store response: {response.status_code} - {response.text}")
                
                if response.status_code != 200:
                    raise HTTPException(
                        status_code=500,
                        detail=f"Failed to save consent: {response.text}"
                    )
                    
            except httpx.RequestError as e:
                raise HTTPException(
                    status_code=503,
                    detail=f"Cannot reach consent store: {str(e)}"
                )
    
    return {"status": "success", "decision": decision.decision}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=BANKING_SERVICE_PORT)
