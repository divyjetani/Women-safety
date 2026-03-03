from fastapi import APIRouter, Query
from datetime import datetime
from database.collections import get_collections

router = APIRouter(prefix="/home", tags=["home"])


@router.get("/safety-stats")
async def get_home_safety_stats(user_id: int = Query(...)):
    collections = get_collections()
    home_stats_col = collections["home_stats"]
    users_col = collections["users"]
    contacts_col = collections["contacts"]
    
    doc = await home_stats_col.find_one({"user_id": user_id}, {"_id": 0})
    user_doc = await users_col.find_one({"id": user_id}, {"_id": 0})
    if not user_doc:
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

    user_stats = user_doc.get("stats") or {}
    guardians_count = await contacts_col.count_documents({"user_id": user_id})

    created_at_raw = user_doc.get("created_at")
    safe_days = int(user_stats.get("safeDays", 0) or 0)
    if created_at_raw:
        try:
            created_dt = datetime.fromisoformat(str(created_at_raw).replace("Z", "+00:00"))
            safe_days = max(1, (datetime.utcnow() - created_dt.replace(tzinfo=None)).days + 1)
        except Exception:
            safe_days = max(1, safe_days)

    await users_col.update_one(
        {"id": user_id},
        {
            "$set": {
                "stats.safeDays": safe_days,
                "stats.guardians": guardians_count,
            }
        },
    )

    if not doc:
        doc = {}

    safety_score = doc.get("safety_score", doc.get("safetyScore", 80))
    safe_zones = doc.get("safe_zones", doc.get("safeZones", 0))
    alerts_today = doc.get("alerts_today", doc.get("alertsToday", 0))
    checkins = int(user_stats.get("checkins", doc.get("checkins", 0)) or 0)
    sos_used = int(user_stats.get("sosUsed", doc.get("sos_used", doc.get("sosUsed", 0))) or 0)

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
    history_col = collections["history"]

    doc = await history_col.find_one({"user_id": user_id}, {"_id": 0, "history": 1})
    if not doc:
        return []

    history_items = doc.get("history", [])
    mapped = []
    for item in history_items[:20]:
        mapped.append(
            {
                "id": item.get("id"),
                "type": item.get("type", "activity"),
                "location": item.get("desc", item.get("location", "Unknown")),
                "time": item.get("time", item.get("created_at", "")),
            }
        )

    return mapped


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
