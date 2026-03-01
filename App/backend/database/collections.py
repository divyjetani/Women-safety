from database.db import get_db


def get_collections():
    db = get_db()
    
    collections = {
        "users": db["users"],
        "contacts": db["contacts"],
        "notifications": db["notifications"],
        "guardians": db["guardians"],
        "history": db["history"],
        "faqs": db["faqs"],
        "home_stats": db["home_stats"],
        "home_activity": db["home_activity"],
        "quick_actions": db["quick_actions"],
        "threat_reports": db["threat_reports"],
        "sos_reports": db["sos_reports"],
        "bubbles": db["bubbles"],
        "invites": db["invites"],
        "groups": db["groups"],
        "shares": db["shares"],
        "sos_events": db["sos_events"],
    }
    
    return collections


async def get_collection(collection_name: str):
    collections = get_collections()
    return collections.get(collection_name)
