from fastapi import APIRouter, HTTPException
from datetime import datetime
from schemas.user import LoginRequest, User
from database.collections import get_collections

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/login")
async def login(request: LoginRequest):
    collections = get_collections()
    users_col = collections["users"]
    
    user = await users_col.find_one({"phone": request.phone}, {"_id": 0})

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return {
        "success": True,
        "user": user,
        "token": f"token_{request.phone}_{int(datetime.now().timestamp())}"
    }


@router.post("/register")
async def register(user: User):
    collections = get_collections()
    users_col = collections["users"]
    
    exists = await users_col.find_one({"phone": user.phone})
    if exists:
        raise HTTPException(status_code=409, detail="User already exists")

    doc = user.dict()
    await users_col.insert_one(doc)
    
    return {
        "success": True,
        "user": doc,
        "token": f"token_{user.phone}_{int(datetime.now().timestamp())}"
    }
