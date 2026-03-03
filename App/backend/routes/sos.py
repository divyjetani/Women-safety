from datetime import datetime
from uuid import uuid4
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from schemas.sos import SOSRequest, SOSResponse, ResolveSOSRequest
from database.collections import get_collections
from services.alert_dispatch_service import send_fcm_notifications, send_sms_fallback

router = APIRouter(prefix="/sos", tags=["sos"])


class SOSMediaUpdateRequest(BaseModel):
    user_id: int
    camera_front_image: Optional[str] = None
    camera_back_image: Optional[str] = None
    audio_10s_url: Optional[str] = None


async def _append_notification(notifs_col, user_id: int, notification: dict):
    existing = await notifs_col.find_one({"user_id": user_id}, {"notifications": 1})
    next_id = 1
    if existing and isinstance(existing.get("notifications"), list):
        ids = [int(n.get("id", 0)) for n in existing["notifications"] if str(n.get("id", "")).isdigit()]
        next_id = (max(ids) if ids else 0) + 1

    notification["id"] = next_id
    await notifs_col.update_one(
        {"user_id": user_id},
        {"$push": {"notifications": notification}},
        upsert=True,
    )


@router.post("", response_model=SOSResponse)
async def create_sos_report(request: SOSRequest):
    collections = get_collections()
    users_col = collections["users"]
    contacts_col = collections["contacts"]
    bubbles_col = collections["bubbles"]
    notifs_col = collections["notifications"]
    history_col = collections["history"]
    sos_events_col = collections["sos_events"]
    home_stats_col = collections["home_stats"]

    user = await users_col.find_one({"id": request.user_id}, {"_id": 0})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    event_id = str(uuid4())
    created_at = datetime.now().isoformat()

    contacts = await contacts_col.find({"user_id": request.user_id}, {"_id": 0}).to_list(length=100)
    emergency_numbers = [c.get("phone") for c in contacts if c.get("phone")]

    associated_bubbles = await bubbles_col.find({"members.user_id": request.user_id}, {"_id": 0}).to_list(length=50)
    bubble_members = []
    for bubble in associated_bubbles:
        for member in bubble.get("members", []):
            if member.get("user_id") != request.user_id:
                bubble_members.append(member)

    members_payload = []
    app_recipient_user_ids = set()
    recipient_tokens = []

    for member in bubble_members:
        member_user_id = member.get("user_id")
        if member_user_id is None:
            continue
        member_user = await users_col.find_one({"id": member_user_id}, {"_id": 0})
        if not member_user:
            continue

        app_recipient_user_ids.add(member_user_id)
        member_tokens = member_user.get("fcm_tokens", [])
        if isinstance(member_tokens, list):
            recipient_tokens.extend(member_tokens)

        members_payload.append(
            {
                "user_id": member_user_id,
                "name": member_user.get("username", member.get("name", "Member")),
                "phone": member_user.get("phone"),
                "location": {
                    "lat": member.get("lat"),
                    "lng": member.get("lng"),
                },
                "battery": member.get("battery"),
            }
        )

    for phone in emergency_numbers:
        contact_user = await users_col.find_one({"phone": phone}, {"_id": 0})
        if contact_user:
            app_recipient_user_ids.add(contact_user.get("id"))
            contact_tokens = contact_user.get("fcm_tokens", [])
            if isinstance(contact_tokens, list):
                recipient_tokens.extend(contact_tokens)

    dispatch_title = f"SOS ALERT: {user.get('username', 'User')}"
    dispatch_body = f"{request.trigger_type.upper()} SOS at {request.location}"
    dispatch_data = {
        "type": "sos_alert",
        "event_id": event_id,
        "user_id": str(request.user_id),
        "location": request.location,
        "trigger_type": request.trigger_type,
        "trigger_reason": request.trigger_reason or "",
    }

    push_result = send_fcm_notifications(recipient_tokens, dispatch_title, dispatch_body, dispatch_data)

    sms_sent_count = 0
    if push_result.get("sent", 0) == 0:
        sms_message = f"SOS ALERT: {user.get('username', 'User')} at {request.location}. Trigger: {request.trigger_reason or request.trigger_type}."
        for phone in emergency_numbers:
            if send_sms_fallback(phone, sms_message):
                sms_sent_count += 1

    event_doc = {
        "id": event_id,
        "user_id": request.user_id,
        "username": user.get("username", ""),
        "location": request.location,
        "lat": request.lat,
        "lng": request.lng,
        "battery": request.battery,
        "message": request.message,
        "trigger_type": request.trigger_type,
        "trigger_reason": request.trigger_reason,
        "camera_front_image": request.camera_front_image,
        "camera_back_image": request.camera_back_image,
        "audio_10s_url": request.audio_10s_url,
        "bubble_code": request.bubble_code,
        "bubble_members": members_payload,
        "contacts_notified": emergency_numbers,
        "dispatch": {
            "push_sent": push_result.get("sent", 0),
            "push_failed": push_result.get("failed", 0),
            "sms_sent": sms_sent_count,
        },
        "police_notified": True,
        "police_note": "Prototype mode: police dispatch simulated.",
        "status": "active",
        "resolved": False,
        "resolved_at": None,
        "resolved_by": None,
        "created_at": created_at,
        "timestamp": request.timestamp.isoformat(),
    }

    await sos_events_col.insert_one(event_doc)
    await collections["sos_reports"].insert_one(event_doc)

    history_item = {
        "id": event_id,
        "type": "sos",
        "title": "SOS Activated",
        "desc": f"{request.trigger_type.capitalize()} trigger at {request.location}",
        "time": created_at,
        "resolved": False,
        "status": "active",
        "trigger_type": request.trigger_type,
        "trigger_reason": request.trigger_reason,
        "battery": request.battery,
    }

    await history_col.update_one(
        {"user_id": request.user_id},
        {"$push": {"history": {"$each": [history_item], "$position": 0}}},
        upsert=True,
    )

    await users_col.update_one({"id": request.user_id}, {"$inc": {"stats.sosUsed": 1}})
    await home_stats_col.update_one({"user_id": request.user_id}, {"$inc": {"sosUsed": 1}})

    await _append_notification(
        notifs_col,
        request.user_id,
        {
            "title": "SOS Submitted",
            "body": "Your SOS details were shared with contacts, bubble members, and police prototype channel.",
            "time": created_at,
            "read": False,
            "type": "alert",
            "cause": request.trigger_reason or request.trigger_type,
            "from_group_member": False,
            "sos_event_id": event_id,
            "member_location": request.location,
            "member_battery": request.battery,
            "member_camera_image": request.camera_front_image or "",
            "audio_10s_url": request.audio_10s_url or "",
        },
    )

    for recipient_user_id in app_recipient_user_ids:
        if not isinstance(recipient_user_id, int):
            continue
        await _append_notification(
            notifs_col,
            recipient_user_id,
            {
                "title": f"SOS from {user.get('username', 'Member')}",
                "body": f"Immediate assistance requested near {request.location}",
                "time": created_at,
                "read": False,
                "type": "threat",
                "cause": request.trigger_reason or request.trigger_type,
                "from_group_member": True,
                "member_name": user.get("username", "Member"),
                "member_location": request.location,
                "member_battery": request.battery,
                "member_camera_image": request.camera_front_image or request.camera_back_image or "",
                "audio_10s_url": request.audio_10s_url or "",
                "sos_event_id": event_id,
            },
        )

    return {
        "success": True,
        "message": "SOS alert sent to emergency contacts, bubble members, and police prototype",
        "report_id": event_id,
    }


@router.patch("/{event_id}/resolve")
async def resolve_sos_event(event_id: str, request: ResolveSOSRequest):
    collections = get_collections()
    sos_events_col = collections["sos_events"]
    history_col = collections["history"]

    now = datetime.now().isoformat()
    update_res = await sos_events_col.update_one(
        {"id": event_id, "user_id": request.user_id},
        {
            "$set": {
                "status": "resolved",
                "resolved": True,
                "resolved_at": now,
                "resolved_by": request.resolved_by or "owner",
                "resolve_reason": request.reason,
            }
        },
    )
    if update_res.matched_count == 0:
        raise HTTPException(status_code=404, detail="SOS event not found")

    await history_col.update_one(
        {"user_id": request.user_id, "history.id": event_id},
        {
            "$set": {
                "history.$.resolved": True,
                "history.$.status": "resolved",
                "history.$.resolved_at": now,
            }
        },
    )

    return {"success": True, "message": "SOS marked as resolved"}


@router.get("/history/{user_id}")
async def get_sos_history(user_id: int):
    collections = get_collections()
    sos_events_col = collections["sos_events"]

    docs = await sos_events_col.find({"user_id": user_id}, {"_id": 0}).sort("created_at", -1).to_list(length=200)
    return {"events": docs}


@router.patch("/{event_id}/media")
async def update_sos_media(event_id: str, body: SOSMediaUpdateRequest):
    collections = get_collections()
    sos_events_col = collections["sos_events"]

    update_fields = {}
    if body.camera_front_image is not None:
        update_fields["camera_front_image"] = body.camera_front_image
    if body.camera_back_image is not None:
        update_fields["camera_back_image"] = body.camera_back_image
    if body.audio_10s_url is not None:
        update_fields["audio_10s_url"] = body.audio_10s_url

    if not update_fields:
        raise HTTPException(status_code=400, detail="No media fields provided")

    update_fields["media_updated_at"] = datetime.now().isoformat()

    res = await sos_events_col.update_one(
        {"id": event_id, "user_id": body.user_id},
        {"$set": update_fields},
    )
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="SOS event not found")

    return {"success": True, "message": "SOS media updated"}
