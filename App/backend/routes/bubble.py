from fastapi import APIRouter, HTTPException
from schemas.group import CreateBubbleReq, JoinBubbleReq, ShareReq
from database.collections import get_collections
from utils.helpers import generate_code, now_iso

router = APIRouter(prefix="/bubble", tags=["bubble"])

def serialize_bubble(b):
    """Serialize bubble document for API responses"""
    b.pop("_id", None)
    return b

@router.post("/create")
async def create_bubble(req: CreateBubbleReq):
    """Create a new bubble with 6-digit invite code"""
    collections = get_collections()
    bubbles_col = collections["bubbles"]
    
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
                "name": req.admin_name, 
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
    member = {
        "user_id": req.user_id, 
        "name": req.name, 
        "lat": None, 
        "lng": None,
        "battery": 100,
        "joined_at": now_iso()
    }
    await bubbles_col.update_one({"code": req.code}, {"$push": {"members": member}})
    
    bubble = await bubbles_col.find_one({"code": req.code}, {"_id": 0})
    
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
    
    bubbles = await bubbles_col.find(
        {"members.user_id": user_id}
    ).to_list(length=100)
    
    for b in bubbles:
        b.pop("_id", None)
    
    return {
        "bubbles": bubbles,
        "count": len(bubbles)
    }

@router.get("/{code}")
async def get_bubble(code: str):
    """Get bubble details by code"""
    collections = get_collections()
    bubbles_col = collections["bubbles"]
    
    bubble = await bubbles_col.find_one({"code": code})
    if not bubble:
        raise HTTPException(status_code=404, detail="Bubble not found")
    
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
async def delete_bubble(code: str, admin_id: int):
    """Delete a bubble (admin only)"""
    collections = get_collections()
    bubbles_col = collections["bubbles"]
    
    bubble = await bubbles_col.find_one({"code": code})
    if not bubble:
        raise HTTPException(status_code=404, detail="Bubble not found")
    
    if bubble.get("admin_id") != admin_id:
        raise HTTPException(status_code=403, detail="Only admin can delete bubble")
    
    await bubbles_col.delete_one({"code": code})
    
    return {
        "success": True,
        "message": "Bubble deleted successfully"
    }


