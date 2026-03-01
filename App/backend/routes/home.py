from fastapi import APIRouter, Query
from database.collections import get_collections

router = APIRouter(prefix="/home", tags=["home"])


@router.get("/safety-stats")
async def get_home_safety_stats(user_id: int = Query(...)):
    collections = get_collections()
    home_stats_col = collections["home_stats"]
    
    doc = await home_stats_col.find_one({"user_id": user_id}, {"_id": 0})
    if not doc:
        return {
            "safety_score": 80,
            "safe_zones": 0,
            "alerts_today": 0,
            "checkins": 0,
            "sos_used": 0,
            "safetyScore": 80,
            "safeZones": 0,
            "alertsToday": 0,
            "sosUsed": 0,
        }

    safety_score = doc.get("safety_score", doc.get("safetyScore", 80))
    safe_zones = doc.get("safe_zones", doc.get("safeZones", 0))
    alerts_today = doc.get("alerts_today", doc.get("alertsToday", 0))
    checkins = doc.get("checkins", 0)
    sos_used = doc.get("sos_used", doc.get("sosUsed", 0))

    return {
        "safety_score": safety_score,
        "safe_zones": safe_zones,
        "alerts_today": alerts_today,
        "checkins": checkins,
        "sos_used": sos_used,
        "safetyScore": safety_score,
        "safeZones": safe_zones,
        "alertsToday": alerts_today,
        "sosUsed": sos_used,
    }


@router.get("/recent-activity")
async def get_home_recent_activity(user_id: int = Query(...)):
    collections = get_collections()
    home_activity_col = collections["home_activity"]
    
    doc = await home_activity_col.find_one({"user_id": user_id}, {"_id": 0})
    if not doc:
        return []
    return doc.get("activity", [])


@router.get("/quick-action/{action}")
async def get_quick_action_details(action: str, user_id: int = Query(...)):
    collections = get_collections()
    quick_actions_col = collections["quick_actions"]
    
    doc = await quick_actions_col.find_one({"action": action}, {"_id": 0})
    if not doc:
        return {
            "title": action,
            "description": "No data found for this action",
            "status": "unknown",
        }
    return doc
