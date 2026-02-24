from fastapi import APIRouter, HTTPException
from database.collections import get_collections

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("/{user_id}")
async def get_notifications(user_id: int):
    collections = get_collections()
    notifs_col = collections["notifications"]
    
    doc = await notifs_col.find_one({"user_id": user_id}, {"_id": 0})
    if not doc:
        return {"notifications": []}
    
    return {"notifications": doc.get("notifications", [])}


@router.put("/{user_id}/{notification_id}/read")
async def mark_read(user_id: int, notification_id: int):
    collections = get_collections()
    notifs_col = collections["notifications"]
    
    res = await notifs_col.update_one(
        {"user_id": user_id, "notifications.id": notification_id},
        {"$set": {"notifications.$.read": True}},
    )
    
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="Notification not found")
    
    return {"success": True, "message": "Notification marked as read"}
