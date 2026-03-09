# App/backend/schemas/sos.py
from pydantic import BaseModel, Field
from typing import Optional, Literal
from datetime import datetime

class SOSRequest(BaseModel):
    user_id: int
    location: str
    lat: Optional[float] = None
    lng: Optional[float] = None
    battery: Optional[int] = Field(default=None, ge=0, le=100)
    trigger_type: Literal["manual", "automatic"] = "manual"
    trigger_reason: Optional[str] = None
    message: Optional[str] = None
    bubble_code: Optional[str] = None
    camera_front_image: Optional[str] = None
    camera_back_image: Optional[str] = None
    audio_10s_url: Optional[str] = None
    timestamp: datetime = Field(default_factory=datetime.now)


class SOSReq(BaseModel):
    user_id: str
    lat: float
    lng: float
    battery: int = Field(ge=0, le=100)
    message: str = "SOS! Need help immediately!"

class SOSResponse(BaseModel):
    success: bool
    message: str
    report_id: str


class ResolveSOSRequest(BaseModel):
    user_id: int
    resolved_by: Optional[str] = None
    reason: Optional[str] = None


class AutomaticSOSStartRequest(BaseModel):
    user_id: int
    reason: str
    location: str
    lat: Optional[float] = None
    lng: Optional[float] = None
    battery: Optional[int] = Field(default=None, ge=0, le=100)
    bubble_code: Optional[str] = None
    camera_front_image: Optional[str] = None
    camera_back_image: Optional[str] = None
    audio_10s_url: Optional[str] = None
    message: Optional[str] = None


class AutomaticSOSCancelRequest(BaseModel):
    user_id: int
    reason: Optional[str] = None


class AutomaticSOSMediaUpdateRequest(BaseModel):
    user_id: int
    camera_front_image: Optional[str] = None
    camera_back_image: Optional[str] = None
    audio_10s_url: Optional[str] = None
