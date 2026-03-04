# App/backend/schemas/profile.py
from pydantic import BaseModel
from typing import Optional, Dict, Any

class AddContact(BaseModel):
    name: str
    phone: str
    isPrimary: bool = False

class UpdateProfile(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    face_image: Optional[str] = None
    aadhar_verified: Optional[bool] = None

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
    phone: str = ""
    face_image: str = ""
    aadhar_verified: bool = False
    isPremium: bool
    stats: ProfileStats
    settings: ProfileSettings
