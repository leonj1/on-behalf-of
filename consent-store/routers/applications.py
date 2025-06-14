from fastapi import APIRouter, HTTPException, Depends
from typing import List
from models.schemas import (
    ApplicationCreate, ApplicationResponse, ApplicationWithCapabilities,
    CapabilityAdd, MessageResponse
)
from database.repository import DatabaseRepository

router = APIRouter(prefix="/applications", tags=["applications"])

def get_repository() -> DatabaseRepository:
    import consent_store
    return consent_store.get_db_repository()

@router.post("", response_model=ApplicationResponse)
def create_application(app: ApplicationCreate, db: DatabaseRepository = Depends(get_repository)):
    """Register a new application"""
    try:
        app_id = db.create_application(app.name)
        app_data = db.get_application(app_id)
        return ApplicationResponse(**app_data)
    except Exception as e:
        if "UNIQUE constraint failed" in str(e):
            raise HTTPException(status_code=409, detail=f"Application '{app.name}' already exists")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("", response_model=List[ApplicationResponse])
def list_applications(db: DatabaseRepository = Depends(get_repository)):
    """List all applications"""
    apps = db.list_applications()
    return [ApplicationResponse(**app) for app in apps]

@router.get("/{app_id}", response_model=ApplicationWithCapabilities)
def get_application(app_id: int, db: DatabaseRepository = Depends(get_repository)):
    """Get application details with capabilities"""
    app = db.get_application(app_id)
    if not app:
        raise HTTPException(status_code=404, detail="Application not found")
    
    capabilities = db.list_capabilities(app_id)
    return ApplicationWithCapabilities(**app, capabilities=capabilities)

@router.delete("/{app_id}", response_model=MessageResponse)
def delete_application(app_id: int, db: DatabaseRepository = Depends(get_repository)):
    """Delete an application"""
    if not db.delete_application(app_id):
        raise HTTPException(status_code=404, detail="Application not found")
    return MessageResponse(message="Application deleted successfully")

@router.put("/{app_id}/capabilities", response_model=MessageResponse)
def add_capability(app_id: int, capability: CapabilityAdd, db: DatabaseRepository = Depends(get_repository)):
    """Add a capability to an application"""
    app = db.get_application(app_id)
    if not app:
        raise HTTPException(status_code=404, detail="Application not found")
    
    if not db.add_capability(app_id, capability.capability):
        raise HTTPException(status_code=409, detail="Capability already exists")
    
    return MessageResponse(message="Capability added successfully")

@router.delete("/{app_id}/capabilities/{capability}", response_model=MessageResponse)
def remove_capability(app_id: int, capability: str, db: DatabaseRepository = Depends(get_repository)):
    """Remove a capability from an application"""
    if not db.remove_capability(app_id, capability):
        raise HTTPException(status_code=404, detail="Capability not found")
    return MessageResponse(message="Capability removed successfully")

@router.get("/{app_id}/capabilities", response_model=List[str])
def list_capabilities(app_id: int, db: DatabaseRepository = Depends(get_repository)):
    """List all capabilities for an application"""
    app = db.get_application(app_id)
    if not app:
        raise HTTPException(status_code=404, detail="Application not found")
    
    return db.list_capabilities(app_id)