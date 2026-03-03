from fastapi import APIRouter, HTTPException
from schemas.group import CreateBubbleReq, JoinBubbleReq, ShareReq
from database.collections import get_collections
from utils.helpers import generate_code, now_iso

router = APIRouter(prefix="/bubble", tags=["bubble"])

def serialize_bubble(b):
    """Serialize bubble document for API responses"""
    b.pop("_id", None)
    return b


async def _resolve_user_display_name(users_col, user_id: int, fallback: str = "") -> str:
    user = await users_col.find_one({"id": user_id}, {"_id": 0, "username": 1, "email": 1})
    if user:
        username = str(user.get("username", "")).strip()
        if username:
            return username
        email = str(user.get("email", "")).strip()
        if email:
            return email.split("@")[0]
    return fallback


async def _hydrate_member_names(bubble: dict, users_col, bubbles_col) -> dict:
    members = bubble.get("members", [])
    changed = False
    hydrated_members = []

    for member in members:
        member_doc = dict(member)
        user_id = member_doc.get("user_id")
        if isinstance(user_id, int):
            current_name = str(member_doc.get("name", "")).strip()
            resolved_name = await _resolve_user_display_name(users_col, user_id, fallback=current_name)
            if resolved_name and resolved_name != current_name:
                member_doc["name"] = resolved_name
                changed = True
        hydrated_members.append(member_doc)

    if changed and bubble.get("code"):
        await bubbles_col.update_one(
            {"code": bubble["code"]},
            {"$set": {"members": hydrated_members}},
        )

    bubble["members"] = hydrated_members
    return bubble

@router.post("/create")
async def create_bubble(req: CreateBubbleReq):
    """Create a new bubble with 6-digit invite code"""
    collections = get_collections()
    bubbles_col = collections["bubbles"]
    users_col = collections["users"]
    admin_name = await _resolve_user_display_name(users_col, req.admin_id, fallback=req.admin_name)
    
    code = generate_code(6)  # Generate 6-digit code
    
    bubble = {
        "code": code,
        "name": req.name,
        "icon": req.icon,
        "color": req.color,
        "admin_id": req.admin_id,
        "members": [
            {
                "user_id": req.admin_id, 
                "name": admin_name,
                "lat": None, 
                "lng": None,
                "battery": 100,
                "joined_at": now_iso()
            }
        ],
        "created_at": now_iso(),
    }
    
    await bubbles_col.insert_one(bubble)
    bubble.pop("_id", None)
    
    return {
        "success": True,
        "group": bubble,
        "code": code,
        "message": "Bubble created successfully"
    }

@router.post("/join")
async def join_bubble(req: JoinBubbleReq):
    """Join a bubble using 6-digit invite code"""
    collections = get_collections()
    bubbles_col = collections["bubbles"]
    users_col = collections["users"]
    
    bubble = await bubbles_col.find_one({"code": req.code})
    if not bubble:
        raise HTTPException(status_code=404, detail="Invalid bubble code")
    
    # Check if user already member
    if any(m.get("user_id") == req.user_id for m in bubble.get("members", [])):
        bubble.pop("_id", None)
        return {
            "success": True,
            "bubble": bubble,
            "message": "Already a member of this bubble"
        }
    
    # Add member to bubble
    member_name = await _resolve_user_display_name(users_col, req.user_id, fallback=req.name)
    member = {
        "user_id": req.user_id, 
        "name": member_name,
        "lat": None, 
        "lng": None,
        "battery": 100,
        "joined_at": now_iso()
    }
    await bubbles_col.update_one({"code": req.code}, {"$push": {"members": member}})
    
    bubble = await bubbles_col.find_one({"code": req.code}, {"_id": 0})
    bubble = await _hydrate_member_names(bubble, users_col, bubbles_col)
    
    return {
        "success": True,
        "bubble": bubble,
        "group": bubble,  # Add for compatibility with frontend
        "message": "Joined bubble successfully"
    }

@router.get("/list/{user_id}")
async def get_user_bubbles(user_id: int):
    """Get all bubbles for a user"""
    collections = get_collections()
    bubbles_col = collections["bubbles"]
    users_col = collections["users"]
    
    bubbles = await bubbles_col.find(
        {"members.user_id": user_id}
    ).to_list(length=100)
    
    for i, b in enumerate(bubbles):
        b = await _hydrate_member_names(b, users_col, bubbles_col)
        b.pop("_id", None)
        bubbles[i] = b
    
    return {
        "bubbles": bubbles,
        "count": len(bubbles)
    }

@router.get("/{code}")
async def get_bubble(code: str):
    """Get bubble details by code"""
    collections = get_collections()
    bubbles_col = collections["bubbles"]
    users_col = collections["users"]
    
    bubble = await bubbles_col.find_one({"code": code})
    if not bubble:
        raise HTTPException(status_code=404, detail="Bubble not found")
    
    bubble = await _hydrate_member_names(bubble, users_col, bubbles_col)
    bubble.pop("_id", None)
    return {"bubble": bubble}

@router.post("/share-location")
async def share_location(req: ShareReq):
    """Share user location with bubble members"""
    collections = get_collections()
    bubbles_col = collections["bubbles"]
    
    # Find all bubbles where this user is a member
    bubbles = await bubbles_col.find(
        {"members.user_id": req.user_id}
    ).to_list(length=100)
    
    if not bubbles:
        # Silently succeed if user not in any bubble yet
        return {
            "success": True,
            "message": "No bubbles to update",
            "bubbles_updated": 0
        }
    
    updated_bubbles = []
    for bubble in bubbles:
        # Update member location in each bubble
        await bubbles_col.update_one(
            {"_id": bubble["_id"], "members.user_id": req.user_id},
            {
                "$set": {
                    "members.$.lat": req.lat,
                    "members.$.lng": req.lng,
                    "members.$.battery": req.battery,
                }
            }
        )
        updated_bubble = await bubbles_col.find_one({"_id": bubble["_id"]}, {"_id": 0})
        updated_bubbles.append(updated_bubble)
    
    return {
        "success": True,
        "message": "Location shared with all bubbles",
        "bubbles_updated": len(updated_bubbles)
    }

@router.delete("/{code}")
async def delete_bubble(code: str, admin_id: int | None = None, user_id: int | None = None):
    """Delete a bubble (admin only)"""
    collections = get_collections()
    bubbles_col = collections["bubbles"]

    actor_id = admin_id if admin_id is not None else user_id
    if actor_id is None:
        raise HTTPException(status_code=422, detail="admin_id or user_id is required")
    
    bubble = await bubbles_col.find_one({"code": code})
    if not bubble:
        raise HTTPException(status_code=404, detail="Bubble not found")
    
    if bubble.get("admin_id") != actor_id:
        raise HTTPException(status_code=403, detail="Only admin can delete bubble")
    
    await bubbles_col.delete_one({"code": code})
    
    return {
        "success": True,
        "message": "Bubble deleted successfully"
    }


@router.post("/{code}/leave")
async def leave_bubble(code: str, user_id: int):
    """Leave a bubble (non-admin members)."""
    collections = get_collections()
    bubbles_col = collections["bubbles"]

    bubble = await bubbles_col.find_one({"code": code})
    if not bubble:
        raise HTTPException(status_code=404, detail="Bubble not found")

    if bubble.get("admin_id") == user_id:
        raise HTTPException(status_code=403, detail="Bubble creator cannot leave. Delete the bubble instead.")

    result = await bubbles_col.update_one(
        {"code": code},
        {"$pull": {"members": {"user_id": user_id}}},
    )

    if result.modified_count == 0:
        raise HTTPException(status_code=404, detail="Member not found in bubble")

    return {
        "success": True,
        "message": "Left bubble successfully",
    }


@router.post("/{code}/kick")
async def kick_member(
    code: str,
    member_user_id: int,
    admin_id: int | None = None,
    user_id: int | None = None,
):
    """Kick a member from bubble (admin only)."""
    collections = get_collections()
    bubbles_col = collections["bubbles"]

    actor_id = admin_id if admin_id is not None else user_id
    if actor_id is None:
        raise HTTPException(status_code=422, detail="admin_id or user_id is required")

    bubble = await bubbles_col.find_one({"code": code})
    if not bubble:
        raise HTTPException(status_code=404, detail="Bubble not found")

    if bubble.get("admin_id") != actor_id:
        raise HTTPException(status_code=403, detail="Only admin can kick members")

    if actor_id == member_user_id:
        raise HTTPException(status_code=400, detail="Admin cannot kick themselves")

    result = await bubbles_col.update_one(
        {"code": code},
        {"$pull": {"members": {"user_id": member_user_id}}},
    )

    if result.modified_count == 0:
        raise HTTPException(status_code=404, detail="Member not found in bubble")

    return {
        "success": True,
        "message": "Member removed successfully",
    }


