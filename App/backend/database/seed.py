# App/backend/database/seed.py
import os
import sys
CURRENT_DIR = os.path.dirname(__file__)
BACKEND_DIR = os.path.dirname(CURRENT_DIR)

if CURRENT_DIR in sys.path:
    sys.path.remove(CURRENT_DIR)
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

import asyncio
from datetime import datetime

from passlib.context import CryptContext
from database.db import connect_db, close_db
from config.settings import MONGO_URL, DATABASE_NAME


pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")


async def seed_database(db):
    users_col = db["users"]
    default_users = [
        {
            "id": 1,
            "username": "Divy",
            "email": "divyjetani2005@gmail.com",
            "phone": "931699087",
            "password_hash": pwd_context.hash("password123"),
            "gender": "female",
            "birthdate": "2001-05-14",
            "face_image": "",
            "aadhar_verified": True,
            "emergency_contacts": ["+91 1234567891", "+91 1234567892"],
            "fcm_tokens": [],
            "is_premium": True,
            "stats": {"safeDays": 128, "sosUsed": 12, "checkins": 45, "guardians": 8},
            "settings": {"notifications": True, "locationSharing": True},
        },
        {
            "id": 2,
            "username": "Divy2",
            "email": "divy2@email.com",
            "phone": "+91 1234567893",
            "password_hash": pwd_context.hash("password123"),
            "gender": "male",
            "birthdate": "1999-11-02",
            "face_image": "",
            "aadhar_verified": False,
            "emergency_contacts": ["+91 1234567894"],
            "fcm_tokens": [],
            "is_premium": False,
            "stats": {"safeDays": 74, "sosUsed": 0, "checkins": 14, "guardians": 3},
            "settings": {"notifications": True, "locationSharing": False},
        },
        {
            "id": 3,
            "username": "Aanya",
            "email": "aanya@email.com",
            "phone": "+1234567895",
            "password_hash": pwd_context.hash("password123"),
            "gender": "female",
            "birthdate": "2000-08-19",
            "face_image": "",
            "aadhar_verified": True,
            "emergency_contacts": [],
            "fcm_tokens": [],
            "is_premium": False,
            "stats": {"safeDays": 33, "sosUsed": 1, "checkins": 8, "guardians": 2},
            "settings": {"notifications": False, "locationSharing": True},
        },
    ]

    for user_doc in default_users:
        await users_col.update_one(
            {"id": user_doc["id"]},
            {"$set": user_doc},
            upsert=True,
        )

    contacts_col = db["contacts"]
    if await contacts_col.count_documents({}) == 0:
        await contacts_col.insert_many([
            {"user_id": 1, "id": 101, "name": "Mom", "phone": "+91 9876543210", "isPrimary": True},
            {"user_id": 1, "id": 102, "name": "Dad", "phone": "+91 9123456789", "isPrimary": False},
            {"user_id": 1, "id": 103, "name": "Best Friend", "phone": "+91 9988776655", "isPrimary": False},
        ])

    notifs_col = db["notifications"]
    if await notifs_col.count_documents({}) == 0:
        await notifs_col.insert_one({
            "user_id": 1,
            "notifications": [
                {"id": 1, "title": "SOS Triggered", "body": "Your SOS was activated successfully.", "time": "2 mins ago", "read": False},
                {"id": 2, "title": "Safe Zone Nearby", "body": "Police station detected within 1.2 km.", "time": "1 hour ago", "read": False},
                {"id": 3, "title": "Weekly Report Ready", "body": "Your safety analytics report is now available.", "time": "Yesterday", "read": True},
            ]
        })

    guardians_col = db["guardians"]
    if await guardians_col.count_documents({}) == 0:
        await guardians_col.insert_one({
            "user_id": 1,
            "guardians": [
                {"id": 1, "name": "Mom", "phone": "+91 90000 11111", "status": "Active"},
                {"id": 2, "name": "Dad", "phone": "+91 90000 22222", "status": "Active"},
                {"id": 3, "name": "Best Friend", "phone": "+91 90000 33333", "status": "Pending"},
            ]
        })

    history_col = db["history"]
    if await history_col.count_documents({}) == 0:
        await history_col.insert_one({
            "user_id": 1,
            "history": [
                {
                    "id": "sos-seed-1",
                    "type": "sos",
                    "title": "SOS Activated",
                    "desc": "SOS triggered from Connaught Place.",
                    "time": "Today 9:12 PM",
                    "status": "active",
                    "resolved": False,
                    "trigger_type": "manual",
                    "trigger_reason": "Manual trigger from app",
                },
                {
                    "id": "history-2",
                    "type": "location",
                    "title": "Location Shared",
                    "desc": "Shared location with Guardians.",
                    "time": "Today 4:01 PM",
                    "status": "completed",
                    "resolved": True,
                },
                {
                    "id": "history-3",
                    "type": "checkin",
                    "title": "Check-in",
                    "desc": "User checked-in as safe.",
                    "time": "Yesterday 8:20 PM",
                    "status": "completed",
                    "resolved": True,
                },
            ]
        })

    faqs_col = db["faqs"]
    if await faqs_col.count_documents({}) == 0:
        await faqs_col.insert_many([
            {"q": "How does SOS work?", "a": "SOS sends alert to guardians with your live location."},
            {"q": "How to add emergency contacts?", "a": "Go to Profile → Emergency Contacts → Add."},
            {"q": "Why safety score changes?", "a": "It depends on time, location, and threat alerts."},
        ])

    home_stats_col = db["home_stats"]
    if await home_stats_col.count_documents({}) == 0:
        await home_stats_col.insert_many([
            {"user_id": 1, "safetyScore": 86, "safeZones": 12, "alertsToday": 2, "checkins": 9, "sosUsed": 1},
            {"user_id": 2, "safetyScore": 74, "safeZones": 6, "alertsToday": 3, "checkins": 4, "sosUsed": 0},
        ])

    home_activity_col = db["home_activity"]
    if await home_activity_col.count_documents({}) == 0:
        await home_activity_col.insert_one({
            "user_id": 1,
            "activity": [
                {"id": 1, "type": "safe_zone", "location": "Metro Station", "time": "2 min ago"},
                {"id": 2, "type": "checkin", "location": "University Campus", "time": "1 hr ago"},
                {"id": 3, "type": "alert", "location": "Unknown Area", "time": "4 hr ago"},
                {"id": 4, "type": "safe_zone", "location": "Home", "time": "Yesterday"},
            ]
        })

    quick_actions_col = db["quick_actions"]
    if await quick_actions_col.count_documents({}) == 0:
        await quick_actions_col.insert_many([
            {
                "action": "share_location",
                "title": "Share Location",
                "description": "Your live location was shared with trusted contacts while traveling.",
                "status": "success",
                "sharedWith": ["Mom", "Dad", "Best Friend"],
                "lastShared": "2 mins ago"
            },
            {
                "action": "emergency_contacts",
                "title": "Emergency Contacts",
                "description": "Emergency contacts loaded successfully.",
                "status": "success",
                "primary": "+91 9876543210",
                "count": 3
            },
            {
                "action": "add_guardian",
                "title": "Add Guardian",
                "description": "Guardian request sent successfully.",
                "status": "pending"
            },
            {
                "action": "alert_police",
                "title": "Alert Police",
                "description": "Nearest police unit has been notified.",
                "status": "success",
                "caseId": "POL-108-2391"
            },
        ])

    threat_reports_col = db["threat_reports"]
    if await threat_reports_col.count_documents({}) == 0:
        await threat_reports_col.insert_many([
            {
                "id": 1,
                "location": "Downtown Mall",
                "threat_level": "low",
                "description": "Safe zone with security",
                "timestamp": datetime.now(),
                "reported_by": 1
            },
            {
                "id": 2,
                "location": "Central Park",
                "threat_level": "medium",
                "description": "Poor lighting at night",
                "timestamp": datetime.now(),
                "reported_by": 2
            },
            {
                "id": 3,
                "location": "Industrial Area",
                "threat_level": "high",
                "description": "Multiple incidents reported",
                "timestamp": datetime.now(),
                "reported_by": 1
            },
        ])

    police_stations_col = db["police_stations"]
    if await police_stations_col.count_documents({}) == 0:
        await police_stations_col.insert_many([
            {
                "id": 1,
                "name": "Navrangpura Police Station",
                "address": "Zone-1, Near Bus Stop, Navrangpura",
                "lat": 23.0400,
                "lng": 72.5700,
            },
            {
                "id": 2,
                "name": "Vastrapur Police Station",
                "address": "Near SAL Hospital, Thaltej Road, Vastrapur",
                "lat": 23.0360,
                "lng": 72.5294,
            },
            {
                "id": 3,
                "name": "Satellite Police Station",
                "address": "Ramdevnagar Cross Road, Satellite",
                "lat": 23.0332,
                "lng": 72.5168,
            },
            {
                "id": 4,
                "name": "Maninagar Police Station",
                "address": "Krishna Baug Cross Road, Maninagar",
                "lat": 23.0000,
                "lng": 72.6000,
            },
            {
                "id": 5,
                "name": "Sabarmati Police Station",
                "address": "Near Rural Bus Stand, Sabarmati",
                "lat": 23.0833,
                "lng": 72.5833,
            },
            {
                "id": 6,
                "name": "Ghatlodiya Police Station",
                "address": "Behind Chandni Apartment, Sola Road",
                "lat": 23.0690,
                "lng": 72.5393,
            },
            {
                "id": 7,
                "name": "Odhav Police Station",
                "address": "Near Adinath Nagar, Odhav GIDC",
                "lat": 23.0322,
                "lng": 72.6753,
            },
            {
                "id": 8,
                "name": "Bapunagar Police Station",
                "address": "Lal Bahadur Shastri Road, Bapunagar",
                "lat": 23.0404,
                "lng": 72.6283,
            },
            {
                "id": 9,
                "name": "Rakhiyal Police Station",
                "address": "Near Monogram Mill, Rakhiyal",
                "lat": 23.0200,
                "lng": 72.6299,
            },
            {
                "id": 10,
                "name": "Isanpur Police Station",
                "address": "Bhairavnath Isanpur Road, Isanpur",
                "lat": 22.9766,
                "lng": 72.5972,
            },
            {
                "id": 11,
                "name": "Dariyapur Police Station",
                "address": "Dariyapur Tower Road, Dariyapur",
                "lat": 23.0436,
                "lng": 72.5826,
            },
            {
                "id": 12,
                "name": "Karanj Police Station",
                "address": "Karanj Bhavan, Bhadra",
                "lat": 23.0238,
                "lng": 72.5828,
            },
            {
                "id": 13,
                "name": "Sola Police Station",
                "address": "Near Sola Civil Hospital, Sola",
                "lat": 23.0810,
                "lng": 72.5350,
            },
            {
                "id": 14,
                "name": "Shahibaug Police Station",
                "address": "Near Shahibaug Under Bridge, Shahibaug",
                "lat": 23.0580,
                "lng": 72.5930,
            },
            {
                "id": 15,
                "name": "Ellisbridge Police Station",
                "address": "Vashram Road, Ellisbridge",
                "lat": 23.0245,
                "lng": 72.5735,
            },
        ])


async def run_seed():
    db = await connect_db()
    await seed_database(db)
    collections_to_check = [
        "users",
        "contacts",
        "notifications",
        "guardians",
        "history",
        "faqs",
        "home_stats",
        "home_activity",
        "quick_actions",
        "threat_reports",
        "police_stations",
    ]
    counts = {}
    for collection_name in collections_to_check:
        counts[collection_name] = await db[collection_name].count_documents({})

    await close_db()
    print(f"Mongo URL: {MONGO_URL}")
    print(f"Database: {DATABASE_NAME}")
    print(f"Counts: {counts}")
    print("Database seeding completed ✅")


if __name__ == "__main__":
    asyncio.run(run_seed())
