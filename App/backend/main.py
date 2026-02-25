from fastapi import FastAPI
from database.db import lifespan_manager
from middleware.cors import add_cors_middleware
from utils.logger import logger

from routes import (
    auth,
    sos,
    profile,
    notifications,
    guardians_history,
    threat_reports,
    home,
    recordings,
    help,
    safety_score,
    analytics,
    groups,
    ai,
    websocket,
    bubble,
)

app = FastAPI(
    title="SheSafe Backend",
    version="2.0.0",
    description="Women Safety Application Backend API",
    lifespan=lifespan_manager,
)

# cors middleware
add_cors_middleware(app)

# api health check
@app.get("/", tags=["health"])
def read_root():
    logger.info("Health check request")
    return {
        "message": "SheSafe API is running ✅",
        "version": "2.0.0",
        "status": "healthy"
    }

# Register all routes
app.include_router(auth.router)
app.include_router(sos.router)
app.include_router(profile.router)
app.include_router(notifications.router)
app.include_router(guardians_history.router)
app.include_router(threat_reports.router)
app.include_router(home.router)
app.include_router(recordings.router)
app.include_router(help.router)
app.include_router(safety_score.router)
app.include_router(analytics.router)
app.include_router(groups.router)
app.include_router(bubble.router)
app.include_router(ai.router)
app.include_router(websocket.router)

logger.info("SheSafe Backend initialized successfully")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
    )
