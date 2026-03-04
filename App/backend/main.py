# App/backend/main.py
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from database.db import lifespan_manager
from middleware.cors import add_cors_middleware
from services.whisper_client import prewarm_whisper_runtime
from utils.logger import logger
from utils.profile_image import PROFILE_PICS_DIR
from config.settings import SOS_MEDIA_DIR, AUDIO_CHUNKS_DIR, ANONYMOUS_RECORDINGS_DIR, FAKECALL_RECORDINGS_DIR

prewarm_whisper_runtime()

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
    police_stations,
)

app = FastAPI(
    title="SheSafe Backend",
    version="2.0.0",
    description="Women Safety Application Backend API",
    lifespan=lifespan_manager,
)

add_cors_middleware(app)

# static files for stored profile images
app.mount("/profile_pics", StaticFiles(directory=str(PROFILE_PICS_DIR)), name="profile_pics")
app.mount("/sos_media", StaticFiles(directory=str(SOS_MEDIA_DIR)), name="sos_media")
app.mount("/audio_chunks", StaticFiles(directory=str(AUDIO_CHUNKS_DIR)), name="audio_chunks")
app.mount("/anonymous_recordings", StaticFiles(directory=str(ANONYMOUS_RECORDINGS_DIR)), name="anonymous_recordings")
app.mount("/fakecall_recordings", StaticFiles(directory=str(FAKECALL_RECORDINGS_DIR)), name="fakecall_recordings")

@app.get("/", tags=["health"])
def read_root():
    logger.info("Health check request")
    return {
        "message": "SheSafe API is running ✅",
        "version": "2.0.0",
        "status": "healthy"
    }

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
app.include_router(police_stations.router)

logger.info("SheSafe Backend initialized successfully")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
    )
