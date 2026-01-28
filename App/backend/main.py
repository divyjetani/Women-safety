# uvicorn main:app --reload --host 0.0.0.0 --port 8000

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone
from fastapi import UploadFile, File, Form
import os
from pathlib import Path
import shutil
import json
from google import genai
from uuid import uuid4

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "AIzaSyBj0oIAl_dY17Xu2f9X04AwO5AmCg1GAjQ") # from main gmail acc
gemini_model = "gemini-2.5-flash"

client = genai.Client(api_key=GEMINI_API_KEY)

class AskAIRequest(BaseModel):
    user_id: int
    question: str
    detailed: bool = False

UPLOAD_DIR = "uploads/recordings"
os.makedirs(UPLOAD_DIR, exist_ok=True)

app = FastAPI(title="SafeGuard Backend", version="1.1.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================
# Models
# ============================================================
class User(BaseModel):
    id: int
    username: str
    email: str
    phone: str
    emergency_contacts: List[str] = []
    is_premium: bool = False

class LoginRequest(BaseModel):
    phone: str

class SOSRequest(BaseModel):
    user_id: int
    location: str
    message: Optional[str] = None
    timestamp: datetime = datetime.now()

class ThreatReport(BaseModel):
    id: int
    location: str
    threat_level: str  # "low", "medium", "high"
    description: str
    timestamp: datetime
    reported_by: int

# Profile APIs Models
class UpdateProfile(BaseModel):
    name: str
    email: str

class UpdateSettings(BaseModel):
    notifications: bool
    locationSharing: bool

class AddContact(BaseModel):
    name: str
    phone: str
    isPrimary: bool = False
class CreateBubbleReq(BaseModel):
    name: str
    icon: int
    color: int
    
BUBBLES = {}       # group_id -> group
INVITES = {}       # token -> group_id


# ============================================================
# Mock Databases
# ============================================================
users_db = {
    1: User(
        id=1,
        username="Sarah",
        email="sarah@email.com",
        phone="+1234567890",
        emergency_contacts=["+1234567891", "+1234567892"],
        is_premium=True,
    ),
    2: User(
        id=2,
        username="John",
        email="john@email.com",
        phone="+1234567893",
        emergency_contacts=["+1234567894"],
        is_premium=False,
    ),
}

sos_reports = []

threat_reports_db = [
    ThreatReport(
        id=1,
        location="Downtown Mall",
        threat_level="low",
        description="Safe zone with security",
        timestamp=datetime.now(),
        reported_by=1,
    ),
    ThreatReport(
        id=2,
        location="Central Park",
        threat_level="medium",
        description="Poor lighting at night",
        timestamp=datetime.now(),
        reported_by=2,
    ),
    ThreatReport(
        id=3,
        location="Industrial Area",
        threat_level="high",
        description="Multiple incidents reported",
        timestamp=datetime.now(),
        reported_by=1,
    ),
]

# ✅ PROFILE DB (for profile screen)
PROFILE_DB: Dict[int, Dict[str, Any]] = {
    1: {
        "name": "Divy Jetani",
        "email": "divy.jetani@email.com",
        "isPremium": True,
        "stats": {"safeDays": 128, "sosUsed": 12, "checkins": 45, "guardians": 8},
        "settings": {"notifications": True, "locationSharing": True},
    }
}

CONTACTS_DB: Dict[int, List[Dict[str, Any]]] = {
    1: [
        {"id": 101, "name": "Mom", "phone": "+91 9876543210", "isPrimary": True},
        {"id": 102, "name": "Dad", "phone": "+91 9123456789", "isPrimary": False},
        {"id": 103, "name": "Best Friend", "phone": "+91 9988776655", "isPrimary": False},
    ]
}

NOTIFS_DB = {
    1: [
        {"id": 1, "title": "SOS Triggered", "body": "Your SOS was activated successfully.", "time": "2 mins ago", "read": False},
        {"id": 2, "title": "Safe Zone Nearby", "body": "Police station detected within 1.2 km.", "time": "1 hour ago", "read": False},
        {"id": 3, "title": "Weekly Report Ready", "body": "Your safety analytics report is now available.", "time": "Yesterday", "read": True},
    ]
}

# ✅ NEW: Guardians DB
GUARDIANS_DB: Dict[int, List[Dict[str, Any]]] = {
    1: [
        {"id": 1, "name": "Mom", "phone": "+91 90000 11111", "status": "Active"},
        {"id": 2, "name": "Dad", "phone": "+91 90000 22222", "status": "Active"},
        {"id": 3, "name": "Best Friend", "phone": "+91 90000 33333", "status": "Pending"},
    ]
}

# ✅ NEW: History DB
HISTORY_DB: Dict[int, List[Dict[str, Any]]] = {
    1: [
        {"id": 1, "title": "SOS Activated", "desc": "SOS triggered from Connaught Place.", "time": "Today 9:12 PM"},
        {"id": 2, "title": "Location Shared", "desc": "Shared location with Guardians.", "time": "Today 4:01 PM"},
        {"id": 3, "title": "Check-in", "desc": "User checked-in as safe.", "time": "Yesterday 8:20 PM"},
    ]
}

# ✅ NEW: Help & Support FAQs
FAQS_DB = [
    {"q": "How does SOS work?", "a": "SOS sends alert to guardians with your live location."},
    {"q": "How to add emergency contacts?", "a": "Go to Profile → Emergency Contacts → Add."},
    {"q": "Why safety score changes?", "a": "It depends on time, location, and threat alerts."},
]

# ✅ NEW: Home safety stats (frontend expects camelCase keys)
HOME_SAFETY_STATS_DB: Dict[int, Dict[str, Any]] = {
    1: {"safetyScore": 86, "safeZones": 12, "alertsToday": 2, "checkins": 9, "sosUsed": 1},
    2: {"safetyScore": 74, "safeZones": 6, "alertsToday": 3, "checkins": 4, "sosUsed": 0},
}

# ✅ NEW: Recent Activity for home (frontend expects list)
HOME_ACTIVITY_DB: Dict[int, List[Dict[str, Any]]] = {
    1: [
        {"id": 1, "type": "safe_zone", "location": "Metro Station", "time": "2 min ago"},
        {"id": 2, "type": "checkin", "location": "University Campus", "time": "1 hr ago"},
        {"id": 3, "type": "alert", "location": "Unknown Area", "time": "4 hr ago"},
        {"id": 4, "type": "safe_zone", "location": "Home", "time": "Yesterday"},
    ]
}

# ✅ NEW: Quick Action details
QUICK_ACTIONS_DB = {
    "share_location": {
        "title": "Share Location",
        "description": "Your live location was shared with guardians.",
        "status": "success",
        "sharedWith": ["Mom", "Dad", "Best Friend"],
        "lastShared": "2 mins ago",
    },
    "emergency_contacts": {
        "title": "Emergency Contacts",
        "description": "Emergency contacts loaded successfully.",
        "primary": "+91 9876543210",
        "count": 3,
    },
    "add_guardian": {
        "title": "Add Guardian",
        "description": "Guardian request sent successfully.",
        "status": "pending",
    },
    "alert_police": {
        "title": "Alert Police",
        "description": "Nearest police unit has been notified.",
        "status": "success",
        "caseId": "POL-108-2391",
    },
}


# ============================================================
# Routes
# ============================================================
@app.get("/")
def read_root():
    return {"message": "SafeGuard API is running ✅"}


# -----------------------------
# AUTH
# -----------------------------
@app.post("/login")
def login(request: LoginRequest):
    """Login with phone number"""
    for user in users_db.values():
        if user.phone == request.phone:
            return {
                "success": True,
                "user": user,
                "token": f"token_{user.id}_{datetime.now().timestamp()}",
            }
    raise HTTPException(status_code=404, detail="User not found")

class AskAIRequest(BaseModel):
    user_id: int
    question: str
    detailed: bool = False

@app.post("/bubble/create")
def create_bubble(req: CreateBubbleReq):
    group_id = str(uuid4())
    invite_token = str(uuid4())

    bubble = {
        "id": group_id,
        "name": req.name,
        "icon": req.icon,
        "color": req.color,
        "members": [],
    }

    BUBBLES[group_id] = bubble
    INVITES[invite_token] = group_id

    return {
        "group": bubble,
        "invite_link": f"safebubble://join/{invite_token}"
    }
    
@app.post("/bubble/join/{token}")
def join_bubble(token: str, user_id: str):
    if token not in INVITES:
        return {"error": "Invalid invite"}

    group_id = INVITES[token]
    bubble = BUBBLES[group_id]

    bubble["members"].append(user_id)

    return bubble



@app.post("/ai/ask")
def ask_ai(req: AskAIRequest):
    try:
        if not req.question.strip():
            raise HTTPException(status_code=400, detail="Question cannot be empty")

        if req.detailed:
            prompt = f"""
You are a helpful safety assistant for a women safety app.
Answer the user question in a detailed way with headings + steps.

User Question: {req.question}

Rules:
- Keep it helpful, safe and clear.
- Use bullet points if needed.
- Give practical steps.
- If user asks anything else except women safety please say, you can't do it, you will only answer for women safety
- do use md file syntax
- max 20 Lines
"""
        else:
            prompt = f"""
You are a helpful safety assistant for a women safety app.
Answer the user question in a short response (max 3 lines).
User Question: {req.question}

Rules:
- Max 3 lines.
- Simple and actionable.
- If user asks anything else except women safety please say, you can't do it, you will only answer for women safety
"""

        response = client.models.generate_content(
            model=gemini_model,
            contents=prompt
        )
        text = (response.text or "").strip()

        # Generate tips
        tips = []
        low = req.question.lower()
        if "sos" in low:
            tips = ["Use SOS quickly", "Share live location", "Keep emergency contacts updated"]
        elif "night" in low or "safe" in low:
            tips = ["Stay in well-lit areas", "Avoid shortcuts", "Keep phone charged"]
        else:
            tips = ["Stay alert", "Share location", "Trust your instincts"]

        if req.detailed:
            return {
                "success": True,
                "short_answer": "",
                "detailed_answer": text,
                "tips": tips
            }

        return {
            "success": True,
            "short_answer": text,
            "detailed_answer": "",
            "tips": tips
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI error: {e}")

@app.get("/users/{user_id}")
def get_user(user_id: int):
    if user_id not in users_db:
        raise HTTPException(status_code=404, detail="User not found")
    return users_db[user_id]


# -----------------------------
# SOS
# -----------------------------
@app.post("/sos")
def create_sos_report(request: SOSRequest):
    sos_reports.append(request)
    return {"success": True, "message": "SOS alert sent to emergency contacts", "report_id": len(sos_reports)}


# -----------------------------
# Threat Reports
# -----------------------------
@app.get("/threat-reports")
def get_threat_reports():
    return threat_reports_db


# ============================================================
# ✅ NEW HOME ENDPOINTS (for new HomeScreen + detail pages)
# ============================================================

@app.get("/home/safety-stats")
def get_home_safety_stats(user_id: int = Query(...)):
    """
    Frontend expects:
    {
      safetyScore, safeZones, alertsToday, checkins, sosUsed
    }
    """
    return HOME_SAFETY_STATS_DB.get(
        user_id,
        {"safetyScore": 80, "safeZones": 0, "alertsToday": 0, "checkins": 0, "sosUsed": 0},
    )


@app.get("/home/recent-activity")
def get_home_recent_activity(user_id: int = Query(...)):
    """
    Frontend expects List:
    [{id,type,location,time}]
    """
    return HOME_ACTIVITY_DB.get(user_id, [])


@app.get("/home/quick-action/{action}")
def get_quick_action_details(action: str, user_id: int = Query(...)):
    """
    Frontend uses this for quick action details pages.
    """
    # user_id is not used heavily in dummy db, but kept for future.
    return QUICK_ACTIONS_DB.get(
        action,
        {"title": action, "description": "No data found for this action", "status": "unknown"},
    )
    
BASE_DIR = Path(__file__).resolve().parent
ANON_DIR = BASE_DIR / "uploads" / "anonymous_recordings"
ANON_DIR.mkdir(parents=True, exist_ok=True)

LOG_FILE = ANON_DIR / "anonymous_log.json"
if not LOG_FILE.exists():
    LOG_FILE.write_text("[]")


@app.post("/recordings/upload-anonymous")
async def upload_anonymous_recording(
    user_id: int = Form(...),
    started_at: str = Form(...),
    ended_at: str = Form(...),
    duration_seconds: int = Form(...),

    start_lat: str = Form(""),
    start_lng: str = Form(""),
    end_lat: str = Form(""),
    end_lng: str = Form(""),

    front_video: UploadFile = File(...),
    back_video: UploadFile = File(...),
    start_image: UploadFile = File(...),
    end_image: UploadFile = File(...),
):
    """
    ✅ Upload anonymous recording:
    - front video
    - back video
    - start image
    - end image
    - start/end location
    """

    try:
        now = datetime.now().strftime("%Y%m%d_%H%M%S")
        unique_id = f"user{user_id}_{now}"

        # ✅ file paths
        front_path = ANON_DIR / f"{unique_id}_front.mp4"
        back_path = ANON_DIR / f"{unique_id}_back.mp4"
        start_img_path = ANON_DIR / f"{unique_id}_start.jpg"
        end_img_path = ANON_DIR / f"{unique_id}_end.jpg"

        # ✅ save files
        with front_path.open("wb") as buffer:
            shutil.copyfileobj(front_video.file, buffer)

        with back_path.open("wb") as buffer:
            shutil.copyfileobj(back_video.file, buffer)

        with start_img_path.open("wb") as buffer:
            shutil.copyfileobj(start_image.file, buffer)

        with end_img_path.open("wb") as buffer:
            shutil.copyfileobj(end_image.file, buffer)

        # ✅ metadata record
        new_record = {
            "id": unique_id,
            "user_id": user_id,
            "started_at": started_at,
            "ended_at": ended_at,
            "duration_seconds": duration_seconds,
            "start_location": {"lat": start_lat, "lng": start_lng},
            "end_location": {"lat": end_lat, "lng": end_lng},
            "files": {
                "front_video": str(front_path),
                "back_video": str(back_path),
                "start_image": str(start_img_path),
                "end_image": str(end_img_path),
            },
            "uploaded_at": datetime.now().isoformat(),
        }

        # ✅ update json log
        data = json.loads(LOG_FILE.read_text())
        data.insert(0, new_record)
        LOG_FILE.write_text(json.dumps(data, indent=2))

        return {
            "success": True,
            "message": "Anonymous recording uploaded successfully ✅",
            "recording": new_record,
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload failed: {e}")
    
# ✅ Folder where recordings will be stored
BASE_DIR = Path(__file__).resolve().parent
RECORDINGS_DIR = BASE_DIR / "uploads" / "fakecall_recordings"
RECORDINGS_DIR.mkdir(parents=True, exist_ok=True)

# ✅ Simple JSON log file
LOG_FILE = RECORDINGS_DIR / "recordings_log.json"
if not LOG_FILE.exists():
    LOG_FILE.write_text("[]")


@app.post("/recordings/upload-fakecall")
async def upload_fakecall_recording(
    user_id: int = Form(...),
    started_at: str = Form(...),
    ended_at: str = Form(...),
    duration_seconds: int = Form(...),

    start_lat: str = Form(""),
    start_lng: str = Form(""),
    end_lat: str = Form(""),
    end_lng: str = Form(""),

    back_video: UploadFile = File(...),
    start_image: UploadFile = File(...),
    end_image: UploadFile = File(...),
):
    """
    ✅ Upload Fake Call recording:
    - back video
    - start image
    - end image
    - start/end location
    """

    now = datetime.now().strftime("%Y%m%d_%H%M%S")
    unique_id = f"user{user_id}_{now}"

    # ✅ File paths
    video_path = RECORDINGS_DIR / f"{unique_id}_back.mp4"
    start_img_path = RECORDINGS_DIR / f"{unique_id}_start.jpg"
    end_img_path = RECORDINGS_DIR / f"{unique_id}_end.jpg"

    # ✅ Save files
    with video_path.open("wb") as buffer:
        shutil.copyfileobj(back_video.file, buffer)

    with start_img_path.open("wb") as buffer:
        shutil.copyfileobj(start_image.file, buffer)

    with end_img_path.open("wb") as buffer:
        shutil.copyfileobj(end_image.file, buffer)

    # ✅ Save metadata log
    new_record = {
        "id": unique_id,
        "user_id": user_id,
        "started_at": started_at,
        "ended_at": ended_at,
        "duration_seconds": duration_seconds,
        "start_location": {"lat": start_lat, "lng": start_lng},
        "end_location": {"lat": end_lat, "lng": end_lng},
        "files": {
            "back_video": str(video_path),
            "start_image": str(start_img_path),
            "end_image": str(end_img_path),
        },
        "uploaded_at": datetime.now().isoformat(),
    }

    data = json.loads(LOG_FILE.read_text())
    data.insert(0, new_record)
    LOG_FILE.write_text(json.dumps(data, indent=2))

    return {
        "success": True,
        "message": "Fake call recording uploaded successfully ✅",
        "recording": new_record,
    }

# ============================================================
# ✅ NEW GUARDIANS / HISTORY / HELP & SUPPORT
# ============================================================

@app.get("/guardians")
def get_guardians(user_id: int = Query(...)):
    return GUARDIANS_DB.get(user_id, [])

@app.get("/history")
def get_history(user_id: int = Query(...)):
    return HISTORY_DB.get(user_id, [])

@app.get("/help/faqs")
def get_faqs():
    return FAQS_DB

# ============================================================
# ✅ PROFILE APIs (same as you had, improved)
# ============================================================

@app.get("/profile/{user_id}")
def get_profile(user_id: int):
    if user_id not in PROFILE_DB:
        PROFILE_DB[user_id] = {
            "name": "New User",
            "email": "newuser@email.com",
            "isPremium": False,
            "stats": {"safeDays": 0, "sosUsed": 0, "checkins": 0, "guardians": 0},
            "settings": {"notifications": True, "locationSharing": True},
        }
    return PROFILE_DB[user_id]

@app.put("/profile/{user_id}")
def update_profile(user_id: int, body: UpdateProfile):
    if user_id not in PROFILE_DB:
        raise HTTPException(status_code=404, detail="User profile not found")

    PROFILE_DB[user_id]["name"] = body.name
    PROFILE_DB[user_id]["email"] = body.email
    return {"success": True, "message": "Profile updated successfully"}

@app.put("/profile/{user_id}/settings")
def update_settings(user_id: int, body: UpdateSettings):
    if user_id not in PROFILE_DB:
        raise HTTPException(status_code=404, detail="User profile not found")

    PROFILE_DB[user_id]["settings"]["notifications"] = body.notifications
    PROFILE_DB[user_id]["settings"]["locationSharing"] = body.locationSharing
    return {"success": True, "message": "Settings updated successfully"}

@app.get("/profile/{user_id}/emergency-contacts")
def get_contacts(user_id: int):
    return {"contacts": CONTACTS_DB.get(user_id, [])}

@app.post("/profile/{user_id}/emergency-contacts")
def add_contact(user_id: int, body: AddContact):
    if user_id not in CONTACTS_DB:
        CONTACTS_DB[user_id] = []

    new_id = 100 + len(CONTACTS_DB[user_id]) + 1

    # if isPrimary => make others false
    if body.isPrimary:
        for c in CONTACTS_DB[user_id]:
            c["isPrimary"] = False

    new_contact = {
        "id": new_id,
        "name": body.name,
        "phone": body.phone,
        "isPrimary": body.isPrimary,
    }

    CONTACTS_DB[user_id].append(new_contact)
    return {"success": True, "contact": new_contact}

@app.delete("/profile/{user_id}/emergency-contacts/{contact_id}")
def delete_contact(user_id: int, contact_id: int):
    CONTACTS_DB[user_id] = [c for c in CONTACTS_DB.get(user_id, []) if c["id"] != contact_id]
    return {"success": True, "message": "Contact deleted"}

@app.put("/profile/{user_id}/emergency-contacts/{contact_id}/primary")
def set_primary(user_id: int, contact_id: int):
    for c in CONTACTS_DB.get(user_id, []):
        c["isPrimary"] = (c["id"] == contact_id)
    return {"success": True, "message": "Primary contact updated"}

# ============================================================
# NOTIFICATIONS
# ============================================================

@app.get("/notifications/{user_id}")
def get_notifications(user_id: int):
    return {"notifications": NOTIFS_DB.get(user_id, [])}


@app.put("/notifications/{user_id}/{notification_id}/read")
def mark_read(user_id: int, notification_id: int):
    for n in NOTIFS_DB.get(user_id, []):
        if n["id"] == notification_id:
            n["read"] = True
            break
    return {"success": True, "message": "Notification marked as read"}

# ============================================================
# Legacy endpoints (kept for backward compatibility)
# ============================================================

@app.get("/safety-stats/{user_id}")
def get_safety_stats_old(user_id: int):
    # old snake_case keys
    return {
        "safety_score": 92,
        "safe_zones": 12,
        "alerts_today": 3,
        "checkins": 24,
        "sos_used": 0,
    }

@app.get("/recent-activity/{user_id}")
def get_recent_activity_old(user_id: int):
    return [
        {"id": 1, "type": "safe_zone", "location": "Downtown Mall", "time": "2 hours ago"},
        {"id": 2, "type": "alert", "location": "Park Street", "time": "4 hours ago"},
        {"id": 3, "type": "checkin", "location": "Home", "time": "6 hours ago"},
    ]

# ============================================================
# Analytics (your old analytics page endpoints)
# ============================================================
@app.get("/analytics/overview")
def analytics_overview():
    return {
        "weeklyTrends": [
            {"day": "Mon", "score": 84},
            {"day": "Tue", "score": 78},
            {"day": "Wed", "score": 90},
            {"day": "Thu", "score": 66},
            {"day": "Fri", "score": 87},
            {"day": "Sat", "score": 73},
            {"day": "Sun", "score": 93},
        ],
        "stats": [
            {
                "id": "threat_prevention",
                "title": "Threat Prevention",
                "value": "94%",
                "trend": 12,
                "color": "#22C55E",
                "subtitle": "Protection success rate",
                "details": "Threat prevention measures worked successfully in 94% of cases. This metric increases when alerts are triggered early and the user reaches safe contacts quickly.",
            },
            {
                "id": "response_time",
                "title": "Response Time",
                "value": "2.4s",
                "trend": -5,
                "color": "#3B82F6",
                "subtitle": "Avg system reaction time",
                "details": "Response time measures how quickly the system triggers actions after detecting a threat signal. Lower is better. Improve by optimizing network + location permissions.",
            },
            {
                "id": "false_alarms",
                "title": "False Alarms",
                "value": "3%",
                "trend": -8,
                "color": "#F59E0B",
                "subtitle": "Unnecessary triggers",
                "details": "False alarms happen when the system triggers emergency mode without real danger. This can reduce trust, so the AI model tries to filter noise patterns carefully.",
            },
            {
                "id": "safe_coverage",
                "title": "Safe Coverage",
                "value": "86%",
                "trend": 15,
                "color": "#A855F7",
                "subtitle": "Area safety availability",
                "details": "Safe coverage reflects how many zones in your area are mapped with safe points like police stations, hospitals, and high-footfall locations.",
            },
        ],
        "peakHours": [
            {"time": "6 PM - 9 PM", "percentage": 0.65, "color": "#EF4444"},
            {"time": "9 PM - 12 AM", "percentage": 0.45, "color": "#F59E0B"},
            {"time": "12 PM - 3 PM", "percentage": 0.25, "color": "#22C55E"},
            {"time": "3 AM - 6 AM", "percentage": 0.15, "color": "#22C55E"},
        ],
        "safetyTips": [
            {"icon": "location", "title": "Live Location Sharing", "description": "Share your live location with trusted contacts while traveling."},
            {"icon": "group", "title": "Use the Buddy System", "description": "Avoid traveling alone at night—stay with friends if possible."},
            {"icon": "light", "title": "Stay in Well-lit Areas", "description": "Avoid isolated shortcuts and prefer crowded streets."},
            {"icon": "battery", "title": "Keep Phone Charged", "description": "Carry a power bank and keep battery above 30%."},
        ],
    }

@app.get("/analytics/stats/{stat_id}")
def stat_detail(stat_id: str):
    mapping = {
        "threat_prevention": {
            "id": "threat_prevention",
            "title": "Threat Prevention",
            "value": "94%",
            "trend": 12,
            "color": "#22C55E",
            "subtitle": "Protection success rate",
            "details": "This card shows how often your safety system prevented a threat situation. Includes: alerts triggered, safe-zone routing, and contact notifications.",
        },
        "response_time": {
            "id": "response_time",
            "title": "Response Time",
            "value": "2.4s",
            "trend": -5,
            "color": "#3B82F6",
            "subtitle": "Avg system reaction time",
            "details": "How quickly your system reacts to risk triggers. Includes server ping, GPS fetch time, and alert dispatch speed.",
        },
        "false_alarms": {
            "id": "false_alarms",
            "title": "False Alarms",
            "value": "3%",
            "trend": -8,
            "color": "#F59E0B",
            "subtitle": "Unnecessary triggers",
            "details": "Shows the % of alerts triggered when there was no real danger. This reduces with better model filtering + confirmation UI.",
        },
        "safe_coverage": {
            "id": "safe_coverage",
            "title": "Safe Coverage",
            "value": "86%",
            "trend": 15,
            "color": "#A855F7",
            "subtitle": "Area safety availability",
            "details": "Shows how strong your surroundings are in terms of mapped safety points. Based on distance to police, hospitals, and crowded zones.",
        },
    }

    return mapping.get(
        stat_id,
        {
            "id": stat_id,
            "title": "Unknown Stat",
            "value": "--",
            "trend": 0,
            "color": "#64748B",
            "subtitle": "No info available",
            "details": "No details found for this stat ID.",
        },
    )

# ----------------------------
# Models
# ----------------------------

class CreateGroupReq(BaseModel):
    name: str = Field(min_length=2, max_length=30)

class AddMemberReq(BaseModel):
    name: str = Field(min_length=2, max_length=40)
    phone: str = Field(min_length=8, max_length=15)

class ShareReq(BaseModel):
    user_id: str
    lat: float
    lng: float
    battery: int = Field(ge=0, le=100)
    incognito: bool = False

class SOSReq(BaseModel):
    user_id: str
    lat: float
    lng: float
    battery: int = Field(ge=0, le=100)
    message: str = "SOS! Need help immediately!"

# ----------------------------
# In-memory DB (dummy)
# ----------------------------

# groups: groupId -> group data
GROUPS: Dict[str, dict] = {}

# shares: groupId -> latest share per userId
LATEST_SHARES: Dict[str, Dict[str, dict]] = {}

# sos: groupId -> list of sos events
SOS_EVENTS: Dict[str, List[dict]] = {}

def now_iso():
    return datetime.now(timezone.utc).isoformat()

def seed_bubble_group():
    """
    Seed your group: bubble
    """
    bubble_id = "bubble"  # ✅ stable group id as "bubble"
    GROUPS[bubble_id] = {
        "id": bubble_id,
        "name": "bubble",
        "members": [
            {"id": "m1", "name": "Mom", "phone": "+91XXXXXXXXXX"},
            {"id": "m2", "name": "Dad", "phone": "+91XXXXXXXXXX"},
        ],
        "created_at": now_iso()
    }
    LATEST_SHARES[bubble_id] = {}
    SOS_EVENTS[bubble_id] = []

seed_bubble_group()

# ----------------------------
# APIs
# ----------------------------

@app.get("/")
def home():
    return {"status": "ok", "message": "Safety Group API running"}

@app.get("/groups")
def list_groups():
    return {"groups": list(GROUPS.values())}

@app.post("/groups")
def create_group(body: CreateGroupReq):
    group_id = body.name.strip().lower()  # simple id
    if group_id in GROUPS:
        raise HTTPException(status_code=409, detail="Group already exists")

    GROUPS[group_id] = {
        "id": group_id,
        "name": body.name.strip(),
        "members": [],
        "created_at": now_iso()
    }
    LATEST_SHARES[group_id] = {}
    SOS_EVENTS[group_id] = []

    return {"message": "Group created", "group": GROUPS[group_id]}

@app.post("/groups/{group_id}/members")
def add_member(group_id: str, body: AddMemberReq):
    if group_id not in GROUPS:
        raise HTTPException(status_code=404, detail="Group not found")

    member = {
        "id": str(uuid.uuid4())[:8],
        "name": body.name.strip(),
        "phone": body.phone.strip()
    }
    GROUPS[group_id]["members"].append(member)
    return {"message": "Member added", "member": member, "group": GROUPS[group_id]}

@app.post("/groups/{group_id}/share")
def share_location(group_id: str, body: ShareReq):
    """
    This is called every few seconds from Flutter
    - If incognito == True => we accept but DO NOT save location
    - If incognito == False => save latest share for that user
    """
    if group_id not in GROUPS:
        raise HTTPException(status_code=404, detail="Group not found")

    if body.incognito:
        return {
            "message": "Incognito ON - share ignored",
            "group_id": group_id,
            "saved": False
        }

    LATEST_SHARES[group_id][body.user_id] = {
        "user_id": body.user_id,
        "lat": body.lat,
        "lng": body.lng,
        "battery": body.battery,
        "updated_at": now_iso(),
    }

    return {
        "message": "Shared successfully",
        "group_id": group_id,
        "saved": True,
        "data": LATEST_SHARES[group_id][body.user_id]
    }

@app.get("/groups/{group_id}/latest")
def get_latest_shares(group_id: str):
    if group_id not in GROUPS:
        raise HTTPException(status_code=404, detail="Group not found")

    return {
        "group_id": group_id,
        "latest": list(LATEST_SHARES[group_id].values())
    }

@app.post("/groups/{group_id}/sos")
def send_sos(group_id: str, body: SOSReq):
    """
    Send SOS alert to all members of group.
    Right now we store event in-memory (dummy).
    Later you will send Firebase push to each member.
    """
    if group_id not in GROUPS:
        raise HTTPException(status_code=404, detail="Group not found")

    event = {
        "id": str(uuid.uuid4()),
        "group_id": group_id,
        "user_id": body.user_id,
        "lat": body.lat,
        "lng": body.lng,
        "battery": body.battery,
        "message": body.message,
        "created_at": now_iso(),
        "notified_members": GROUPS[group_id]["members"],  # dummy
    }

    SOS_EVENTS[group_id].append(event)

    return {"message": "SOS triggered", "event": event}

@app.get("/groups/{group_id}/sos")
def list_sos(group_id: str):
    if group_id not in GROUPS:
        raise HTTPException(status_code=404, detail="Group not found")
    return {"group_id": group_id, "events": SOS_EVENTS[group_id]}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

# uvicorn main:app --reload --host 0.0.0.0 --port 800
