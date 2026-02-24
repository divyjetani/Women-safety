from fastapi import APIRouter
from schemas.common import LocationRequest
from services.safety_service import SafetyScoreService
from utils.logger import logger

router = APIRouter(tags=["safety"])

try:
    safety_service = SafetyScoreService()
except Exception as e:
    logger.error(f"Failed to initialize SafetyScoreService: {e}")
    safety_service = None


@router.post("/safety-score")
async def get_safety_score(req: LocationRequest):
    if not safety_service:
        return {"risk_score": 50.0, "error": "Safety service not available"}
    
    try:
        risk_score = safety_service.get_safety_score(req.latitude, req.longitude)
        return {"risk_score": risk_score}
    except Exception as e:
        logger.error(f"Error calculating safety score: {e}")
        return {"risk_score": 50.0, "error": str(e)}
