from fastapi import APIRouter, HTTPException
from schemas.profile import (
    Profile,
    UpdateProfile,
    UpdateSettings,
    AddContact,
)
from database.collections import get_collections

router = APIRouter(prefix="/profile", tags=["profile"])


@router.get("/{user_id}", response_model=Profile)
async def get_profile(user_id: int):
    collections = get_collections()
    users_col = collections["users"]

    user_doc = await users_col.find_one({"id": user_id}, {"_id": 0, "password_hash": 0})
    if not user_doc:
        raise HTTPException(status_code=404, detail="User not found")

    settings = user_doc.get("settings") or {}
    stats = user_doc.get("stats") or {}

    return {
        "user_id": user_id,
        "name": user_doc.get("username", "New User"),
        "email": user_doc.get("email", ""),
        "phone": user_doc.get("phone", ""),
        "face_image": user_doc.get("face_image", ""),
        "aadhar_verified": user_doc.get("aadhar_verified", False),
        "isPremium": user_doc.get("is_premium", False),
        "stats": {
            "safeDays": stats.get("safeDays", 0),
            "sosUsed": stats.get("sosUsed", 0),
            "checkins": stats.get("checkins", 0),
            "guardians": stats.get("guardians", 0),
        },
        "settings": {
            "notifications": settings.get("notifications", True),
            "locationSharing": settings.get("locationSharing", True),
        },
    }


@router.put("/{user_id}")
async def update_profile(user_id: int, body: UpdateProfile):
    collections = get_collections()
    users_col = collections["users"]
    user_updates = {}

    if body.name is not None:
        user_updates["username"] = body.name

    if body.email is not None:
        normalized_email = body.email.strip().lower()
        user_updates["email"] = normalized_email

    if body.phone is not None:
        user_updates["phone"] = body.phone

    if body.face_image is not None:
        user_updates["face_image"] = body.face_image

    if body.aadhar_verified is not None:
        user_updates["aadhar_verified"] = body.aadhar_verified

    if user_updates:
        result = await users_col.update_one(
            {"id": user_id},
            {"$set": user_updates},
        )
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="User not found")
    
    return {"success": True, "message": "Profile updated successfully"}


@router.put("/{user_id}/settings")
async def update_settings(user_id: int, body: UpdateSettings):
    collections = get_collections()
    users_col = collections["users"]
    
    res = await users_col.update_one(
        {"id": user_id},
        {
            "$set": {
                "settings.notifications": body.notifications,
                "settings.locationSharing": body.locationSharing,
            }
        },
    )
    
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="User not found")
    
    return {"success": True, "message": "Settings updated successfully"}


@router.get("/{user_id}/emergency-contacts")
async def get_contacts(user_id: int):
    collections = get_collections()
    contacts_col = collections["contacts"]
    
    docs = await contacts_col.find({"user_id": user_id}).to_list(length=100)
    for d in docs:
        d.pop("_id", None)
    
    return {"contacts": docs}


@router.post("/{user_id}/emergency-contacts")
async def add_contact(user_id: int, body: AddContact):
    collections = get_collections()
    contacts_col = collections["contacts"]
    
    count = await contacts_col.count_documents({"user_id": user_id})
    new_id = 100 + count + 1

    if body.isPrimary:
        await contacts_col.update_many({"user_id": user_id}, {"$set": {"isPrimary": False}})

    new_contact = {
        "user_id": user_id,
        "id": new_id,
        "name": body.name,
        "phone": body.phone,
        "isPrimary": body.isPrimary,
    }
    await contacts_col.insert_one(new_contact)
    
    return {"success": True, "contact": new_contact}


@router.delete("/{user_id}/emergency-contacts/{contact_id}")
async def delete_contact(user_id: int, contact_id: int):
    collections = get_collections()
    contacts_col = collections["contacts"]
    
    await contacts_col.delete_one({"user_id": user_id, "id": contact_id})
    
    return {"success": True, "message": "Contact deleted"}


@router.put("/{user_id}/emergency-contacts/{contact_id}/primary")
async def set_primary_contact(user_id: int, contact_id: int):
    collections = get_collections()
    contacts_col = collections["contacts"]
    
    await contacts_col.update_many({"user_id": user_id}, {"$set": {"isPrimary": False}})
    
    await contacts_col.update_one(
        {"user_id": user_id, "id": contact_id},
        {"$set": {"isPrimary": True}},
    )
    
    return {"success": True, "message": "Primary contact updated"}
