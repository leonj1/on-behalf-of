from pydantic import BaseModel
from typing import List, Optional, Dict
from datetime import datetime

# Application schemas
class ApplicationCreate(BaseModel):
    name: str

class ApplicationResponse(BaseModel):
    id: int
    name: str
    created_at: datetime

class ApplicationWithCapabilities(ApplicationResponse):
    capabilities: List[str]

# Capability schemas
class CapabilityAdd(BaseModel):
    capability: str

class CapabilityRemove(BaseModel):
    capability: str

# Consent schemas
class ConsentGrant(BaseModel):
    user_id: str
    requesting_app_name: str
    destination_app_name: str
    capabilities: List[str]

class ConsentCheck(BaseModel):
    user_id: str
    requesting_app_name: str
    destination_app_name: str
    capabilities: List[str]

class ConsentCheckResponse(BaseModel):
    granted: Dict[str, bool]
    all_granted: bool

class ConsentRevoke(BaseModel):
    user_id: str
    requesting_app_name: str
    destination_app_name: str
    capability: str

class UserConsent(BaseModel):
    id: int
    user_id: str
    requesting_app_id: int
    requesting_app_name: str
    destination_app_id: int
    destination_app_name: str
    capability: str
    granted_at: datetime

# Response models
class MessageResponse(BaseModel):
    message: str

class CountResponse(BaseModel):
    count: int