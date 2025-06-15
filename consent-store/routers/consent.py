from fastapi import APIRouter, HTTPException, Depends
from typing import List
from models.schemas import (
    ConsentGrant, ConsentCheck, ConsentCheckResponse, ConsentRevoke,
    UserConsent, MessageResponse, CountResponse
)
from database.repository import DatabaseRepository

router = APIRouter(prefix="/consent", tags=["consent"])

def get_repository() -> DatabaseRepository:
    import consent_store
    return consent_store.get_db_repository()

@router.post("", response_model=MessageResponse)
def grant_consent(consent: ConsentGrant, db: DatabaseRepository = Depends(get_repository)):
    """Record user consent for an application to use another application's capabilities"""
    # Get application IDs
    requesting_app = db.get_application_by_name(consent.requesting_app_name)
    if not requesting_app:
        raise HTTPException(status_code=404, detail=f"Requesting application '{consent.requesting_app_name}' not found")
    
    destination_app = db.get_application_by_name(consent.destination_app_name)
    if not destination_app:
        raise HTTPException(status_code=404, detail=f"Destination application '{consent.destination_app_name}' not found")
    
    # Verify capabilities exist for destination app
    dest_capabilities = db.list_capabilities(destination_app['id'])
    for capability in consent.capabilities:
        if capability not in dest_capabilities:
            raise HTTPException(
                status_code=400,
                detail=f"Capability '{capability}' not found for application '{consent.destination_app_name}'"
            )
    
    # Grant consent for each capability
    for capability in consent.capabilities:
        db.grant_consent(
            consent.user_id,
            requesting_app['id'],
            destination_app['id'],
            capability
        )
    
    return MessageResponse(message="Consent granted successfully")

@router.get("/check", response_model=ConsentCheckResponse)
def check_consent(consent: ConsentCheck = Depends(), db: DatabaseRepository = Depends(get_repository)):
    """Check if user has granted consent for specific capabilities"""
    # Get application IDs
    requesting_app = db.get_application_by_name(consent.requesting_app_name)
    if not requesting_app:
        raise HTTPException(status_code=404, detail=f"Requesting application '{consent.requesting_app_name}' not found")
    
    destination_app = db.get_application_by_name(consent.destination_app_name)
    if not destination_app:
        raise HTTPException(status_code=404, detail=f"Destination application '{consent.destination_app_name}' not found")
    
    # Check consent
    granted = db.check_consent(
        consent.user_id,
        requesting_app['id'],
        destination_app['id'],
        consent.capabilities
    )
    
    all_granted = all(granted.values())
    
    return ConsentCheckResponse(granted=granted, all_granted=all_granted)

@router.post("/check", response_model=ConsentCheckResponse)
def check_consent_post(consent: ConsentCheck, db: DatabaseRepository = Depends(get_repository)):
    """Check if user has granted consent for specific capabilities (POST version)"""
    # Get application IDs
    requesting_app = db.get_application_by_name(consent.requesting_app_name)
    if not requesting_app:
        raise HTTPException(status_code=404, detail=f"Requesting application '{consent.requesting_app_name}' not found")
    
    destination_app = db.get_application_by_name(consent.destination_app_name)
    if not destination_app:
        raise HTTPException(status_code=404, detail=f"Destination application '{consent.destination_app_name}' not found")
    
    # Check consent
    granted = db.check_consent(
        consent.user_id,
        requesting_app['id'],
        destination_app['id'],
        consent.capabilities
    )
    
    all_granted = all(granted.values())
    
    return ConsentCheckResponse(granted=granted, all_granted=all_granted)

@router.delete("/user/{user_id}/capability", response_model=MessageResponse)
def revoke_specific_consent(user_id: str, revoke: ConsentRevoke, db: DatabaseRepository = Depends(get_repository)):
    """Revoke specific consent for a user"""
    # Get application IDs
    requesting_app = db.get_application_by_name(revoke.requesting_app_name)
    if not requesting_app:
        raise HTTPException(status_code=404, detail=f"Requesting application '{revoke.requesting_app_name}' not found")
    
    destination_app = db.get_application_by_name(revoke.destination_app_name)
    if not destination_app:
        raise HTTPException(status_code=404, detail=f"Destination application '{revoke.destination_app_name}' not found")
    
    if not db.revoke_consent(user_id, requesting_app['id'], destination_app['id'], revoke.capability):
        raise HTTPException(status_code=404, detail="Consent not found")
    
    return MessageResponse(message="Consent revoked successfully")

@router.delete("/user/{user_id}", response_model=CountResponse)
def revoke_all_user_consent(user_id: str, db: DatabaseRepository = Depends(get_repository)):
    """Clear all consent for a specific user"""
    count = db.revoke_all_user_consent(user_id)
    return CountResponse(count=count)

@router.delete("/all", response_model=CountResponse)
def revoke_all_consent(db: DatabaseRepository = Depends(get_repository)):
    """Clear all consent in the system"""
    count = db.revoke_all_consent()
    return CountResponse(count=count)

@router.get("/user/{user_id}", response_model=List[UserConsent])
def list_user_consents(user_id: str, db: DatabaseRepository = Depends(get_repository)):
    """List all consents for a specific user"""
    consents = db.list_user_consents(user_id)
    return [UserConsent(**consent) for consent in consents]