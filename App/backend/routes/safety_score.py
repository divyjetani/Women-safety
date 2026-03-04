# App/backend/routes/safety_score.py
from datetime import datetime
from fastapi import APIRouter, Query
from schemas.common import LocationRequest
from services.safety_service import SafetyScoreService
from utils.logger import logger
from database.collections import get_collections

router = APIRouter(tags=["safety"])

try:
    safety_service = SafetyScoreService()
except Exception as e:
    logger.error(f"Failed to initialize SafetyScoreService: {e}")
    safety_service = None


@router.post("/safety-score")
async def get_safety_score(req: LocationRequest, user_id: int | None = Query(default=None)):
    if not safety_service:
        return {"risk_score": 50.0, "error": "Safety service not available"}
    
    try:
        risk_score = safety_service.get_safety_score(req.latitude, req.longitude)

        if user_id is not None:
            collections = get_collections()
            home_stats_col = collections["home_stats"]
            score_int = int(round(risk_score))

            await home_stats_col.update_one(
                {"user_id": user_id},
                {
                    "$set": {
                        "user_id": user_id,
                        "safety_score": score_int,
                        "safetyScore": score_int,
                        "last_safety_lat": req.latitude,
                        "last_safety_lng": req.longitude,
                        "last_safety_updated_at": datetime.utcnow().isoformat(),
                    },
                    "$setOnInsert": {
                        "safe_zones": 0,
                        "alerts_today": 0,
                        "checkins": 0,
                        "sos_used": 0,
                    },
                },
                upsert=True,
            )

        return {"risk_score": risk_score}
    except Exception as e:
        logger.error(f"Error calculating safety score: {e}")
        return {"risk_score": 50.0, "error": str(e)}
