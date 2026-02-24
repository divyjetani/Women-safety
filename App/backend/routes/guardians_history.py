from fastapi import APIRouter, Query
from database.collections import get_collections

router = APIRouter(tags=["guardians", "history"])


@router.get("/guardians")
async def get_guardians(user_id: int = Query(...)):
    collections = get_collections()
    guardians_col = collections["guardians"]
    
    doc = await guardians_col.find_one({"user_id": user_id}, {"_id": 0})
    if not doc:
        return []
    
    return doc.get("guardians", [])


@router.get("/history")
async def get_history(user_id: int = Query(...)):
    collections = get_collections()
    history_col = collections["history"]
    
    doc = await history_col.find_one({"user_id": user_id}, {"_id": 0})
    if not doc:
        return []
    
    return doc.get("history", [])
