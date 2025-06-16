from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database.sqlite_repository import SQLiteRepository
from database.repository import DatabaseRepository
from routers import applications, consent
import sys
sys.path.append('/app')  # Add app directory to path
from config import *

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

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:3001", "http://localhost:3005", f"http://{FRONTEND_EXTERNAL_IP}:{FRONTEND_PORT}", f"http://{EXTERNAL_IP}:{FRONTEND_PORT}"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
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