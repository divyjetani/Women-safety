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
            "safetyScore": 80,
            "safeZones": 0,
            "alertsToday": 0,
            "checkins": 0,
            "sosUsed": 0,
        }
    return doc


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
