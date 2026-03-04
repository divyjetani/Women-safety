# App/backend/routes/groups.py
from fastapi import APIRouter, HTTPException
from uuid import uuid4
from schemas.group import (
    CreateGroupReq,
    AddMemberReq,
    ShareReq,
)
from database.collections import get_collections
from utils.helpers import now_iso

router = APIRouter(tags=["groups"])

@router.get("/groups")
async def list_groups():
    collections = get_collections()
    groups_col = collections["groups"]
    
    docs = await groups_col.find().to_list(length=100)
    for d in docs:
        d.pop("_id", None)
    return {"groups": docs}


@router.post("/groups")
async def create_group(body: CreateGroupReq):
    collections = get_collections()
    groups_col = collections["groups"]
    
    group_id = body.name.strip().lower()
    exists = await groups_col.find_one({"id": group_id})
    if exists:
        raise HTTPException(status_code=409, detail="Group already exists")

    group = {
        "id": group_id,
        "name": body.name.strip(),
        "members": [],
        "created_at": now_iso(),
    }
    await groups_col.insert_one(group)
    
    return {"message": "Group created", "group": group}


@router.post("/groups/{group_id}/members")
async def add_member(group_id: str, body: AddMemberReq):
    collections = get_collections()
    groups_col = collections["groups"]
    
    group = await groups_col.find_one({"id": group_id})
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")

    member = {
        "id": str(uuid4())[:8],
        "name": body.name.strip(),
        "phone": body.phone.strip(),
    }
    await groups_col.update_one({"id": group_id}, {"$push": {"members": member}})
    group = await groups_col.find_one({"id": group_id}, {"_id": 0})
    
    return {"message": "Member added", "member": member, "group": group}


@router.post("/groups/{group_id}/share")
async def share_location(group_id: str, body: ShareReq):
    collections = get_collections()
    groups_col = collections["groups"]
    shares_col = collections["shares"]
    
    group = await groups_col.find_one({"id": group_id})
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")

    if body.incognito:
        return {
            "message": "Incognito ON - share ignored",
            "group_id": group_id,
            "saved": False,
        }

    data = {
        "group_id": group_id,
        "user_id": body.user_id,
        "lat": body.lat,
        "lng": body.lng,
        "battery": body.battery,
        "updated_at": now_iso(),
    }
    await shares_col.update_one(
        {"group_id": group_id, "user_id": body.user_id},
        {"$set": data},
        upsert=True,
    )
    
    return {
        "message": "Shared successfully",
        "group_id": group_id,
        "saved": True,
        "data": data,
    }


@router.get("/groups/{group_id}/latest")
async def get_latest_shares(group_id: str):
    collections = get_collections()
    groups_col = collections["groups"]
    shares_col = collections["shares"]
    
    group = await groups_col.find_one({"id": group_id})
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")

    docs = await shares_col.find({"group_id": group_id}).to_list(length=100)
    for d in docs:
        d.pop("_id", None)
    
    return {"group_id": group_id, "latest": docs}


@router.post("/groups/{group_id}/sos")
async def send_sos(group_id: str, body):
    from schemas.sos import SOSReq
    
    collections = get_collections()
    groups_col = collections["groups"]
    sos_events_col = collections["sos_events"]
    
    group = await groups_col.find_one({"id": group_id})
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")

    event = {
        "id": str(uuid4()),
        "group_id": group_id,
        "user_id": body.user_id,
        "lat": body.lat,
        "lng": body.lng,
        "battery": body.battery,
        "message": body.message,
        "created_at": now_iso(),
        "notified_members": group.get("members", []),
    }
    await sos_events_col.insert_one(event)
    
    return {"message": "SOS triggered", "event": event}


@router.get("/groups/{group_id}/sos")
async def list_sos(group_id: str):
    collections = get_collections()
    groups_col = collections["groups"]
    sos_events_col = collections["sos_events"]
    
    group = await groups_col.find_one({"id": group_id})
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
    
    docs = await sos_events_col.find({"group_id": group_id}).to_list(length=100)
    for d in docs:
        d.pop("_id", None)
    
    return {"group_id": group_id, "events": docs}
