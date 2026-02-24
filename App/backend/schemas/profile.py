from pydantic import BaseModel
from typing import Optional, Dict, Any

class AddContact(BaseModel):
    name: str
    phone: str
    isPrimary: bool = False

class UpdateProfile(BaseModel):
    name: str
    email: str

class UpdateSettings(BaseModel):
    notifications: bool
    locationSharing: bool

class ContactResponse(BaseModel):
    user_id: int
    id: int
    name: str
    phone: str
    isPrimary: bool

class ProfileStats(BaseModel):
    safeDays: int
    sosUsed: int
    checkins: int
    guardians: int

class ProfileSettings(BaseModel):
    notifications: bool
    locationSharing: bool

class Profile(BaseModel):
    user_id: int
    name: str
    email: str
    isPremium: bool
    stats: ProfileStats
    settings: ProfileSettings
