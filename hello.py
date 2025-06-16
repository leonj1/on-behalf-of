from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from config import (
    FRONTEND_EXTERNAL_IP,
    FRONTEND_PORT,
    EXTERNAL_IP,
    HELLO_SERVICE_PORT,
    FRONTEND_EXTERNAL_URL
)

app = FastAPI(
    title="Hello Service",
    description="Simple unprotected service",
    version="1.0.0"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000", 
        "http://localhost:3001", 
        "http://localhost:3005", 
        f"http://{FRONTEND_EXTERNAL_IP}:{FRONTEND_PORT}", 
        f"http://{EXTERNAL_IP}:{FRONTEND_PORT}",
        FRONTEND_EXTERNAL_URL,
        "https://consent.joseserver.com"
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def root():
    return {"message": "Hello Service", "version": "1.0.0"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}

@app.get("/hello")
def say_hello():
    """Simple hello endpoint that always returns 200"""
    return "hi there!"

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=HELLO_SERVICE_PORT)