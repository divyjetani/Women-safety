from fastapi import APIRouter, HTTPException
from schemas.profile import (
    Profile,
    UpdateProfile,
    UpdateSettings,
    AddContact,
    ContactResponse,
    ProfileStats,
    ProfileSettings,
)
from database.collections import get_collections

router = APIRouter(prefix="/profile", tags=["profile"])


@router.get("/{user_id}", response_model=Profile)
async def get_profile(user_id: int):
    collections = get_collections()
    profiles_col = collections["profiles"]
    
    profile = await profiles_col.find_one({"user_id": user_id}, {"_id": 0})

    if not profile:
        profile = {
            "user_id": user_id,
            "name": "New User",
            "email": "",
            "isPremium": False,
            "stats": {"safeDays": 0, "sosUsed": 0, "checkins": 0, "guardians": 0},
            "settings": {"notifications": True, "locationSharing": True},
        }
        await profiles_col.insert_one(profile)

    return profile


@router.put("/{user_id}")
async def update_profile(user_id: int, body: UpdateProfile):
    collections = get_collections()
    profiles_col = collections["profiles"]
    
    res = await profiles_col.update_one(
        {"user_id": user_id},
        {"$set": {"name": body.name, "email": body.email}}
    )
    
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="User profile not found")
    
    return {"success": True, "message": "Profile updated successfully"}


@router.put("/{user_id}/settings")
async def update_settings(user_id: int, body: UpdateSettings):
    collections = get_collections()
    profiles_col = collections["profiles"]
    
    res = await profiles_col.update_one(
        {"user_id": user_id},
        {
            "$set": {
                "settings.notifications": body.notifications,
                "settings.locationSharing": body.locationSharing,
            }
        },
    )
    
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="User profile not found")
    
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
