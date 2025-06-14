from abc import ABC, abstractmethod
from typing import List, Optional, Dict, Any

class DatabaseRepository(ABC):
    """Abstract base class for database operations"""
    
    @abstractmethod
    def create_application(self, name: str) -> int:
        """Create a new application and return its ID"""
        pass
    
    @abstractmethod
    def get_application(self, app_id: int) -> Optional[Dict[str, Any]]:
        """Get application by ID"""
        pass
    
    @abstractmethod
    def get_application_by_name(self, name: str) -> Optional[Dict[str, Any]]:
        """Get application by name"""
        pass
    
    @abstractmethod
    def list_applications(self) -> List[Dict[str, Any]]:
        """List all applications"""
        pass
    
    @abstractmethod
    def delete_application(self, app_id: int) -> bool:
        """Delete an application and all its related data"""
        pass
    
    @abstractmethod
    def add_capability(self, app_id: int, capability: str) -> bool:
        """Add a capability to an application"""
        pass
    
    @abstractmethod
    def remove_capability(self, app_id: int, capability: str) -> bool:
        """Remove a capability from an application"""
        pass
    
    @abstractmethod
    def list_capabilities(self, app_id: int) -> List[str]:
        """List all capabilities for an application"""
        pass
    
    @abstractmethod
    def grant_consent(self, user_id: str, requesting_app_id: int, 
                     destination_app_id: int, capability: str) -> bool:
        """Grant user consent for an app to use another app's capability"""
        pass
    
    @abstractmethod
    def check_consent(self, user_id: str, requesting_app_id: int,
                     destination_app_id: int, capabilities: List[str]) -> Dict[str, bool]:
        """Check if user has granted consent for specific capabilities"""
        pass
    
    @abstractmethod
    def revoke_consent(self, user_id: str, requesting_app_id: int,
                      destination_app_id: int, capability: str) -> bool:
        """Revoke specific consent"""
        pass
    
    @abstractmethod
    def revoke_all_user_consent(self, user_id: str) -> int:
        """Revoke all consent for a specific user, return count of revoked consents"""
        pass
    
    @abstractmethod
    def revoke_all_consent(self) -> int:
        """Revoke all consent in the system, return count of revoked consents"""
        pass
    
    @abstractmethod
    def list_user_consents(self, user_id: str) -> List[Dict[str, Any]]:
        """List all consents for a specific user"""
        pass