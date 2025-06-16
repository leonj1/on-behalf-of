from fastapi import FastAPI, Response, Request
from fastapi.middleware.cors import CORSMiddleware
from database.sqlite_repository import SQLiteRepository
from database.repository import DatabaseRepository
from routers import applications, consent
import sys
sys.path.append('/app')  # Add app directory to path
from config import (
    FRONTEND_EXTERNAL_IP,
    FRONTEND_PORT,
    EXTERNAL_IP,
    CONSENT_STORE_PORT,
    FRONTEND_EXTERNAL_URL
)

# Initialize the database repository
_db_repository: DatabaseRepository = None

def get_db_repository() -> DatabaseRepository:
    global _db_repository
    if _db_repository is None:
        _db_repository = SQLiteRepository()
    return _db_repository

# Create FastAPI app
app = FastAPI(
    title="Consent Store API",
    description="Service for managing application capabilities and user consent",
    version="1.0.0"
)

# FORCE CORS headers on ALL responses using custom middleware
@app.middleware("http") 
async def force_cors_headers(request, call_next):
    response = await call_next(request)
    
    # Add CORS headers to every response
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "*"
    response.headers["Access-Control-Max-Age"] = "3600"
    
    return response

# Also handle OPTIONS requests at the app level
@app.options("/{path:path}")
async def global_options_handler():
    """Handle all OPTIONS requests globally"""
    return Response(
        status_code=200,
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
            "Access-Control-Allow-Headers": "*",
            "Access-Control-Max-Age": "3600",
        }
    )

# Include routers
app.include_router(applications.router)
app.include_router(consent.router)

@app.get("/")
def root():
    return {"message": "Consent Store API", "version": "1.0.0"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=CONSENT_STORE_PORT)