from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime


class CreateGroupReq(BaseModel):
    name: str = Field(min_length=2, max_length=30)


class AddMemberReq(BaseModel):
    name: str = Field(min_length=2, max_length=40)
    phone: str = Field(min_length=8, max_length=15)


class ShareReq(BaseModel):
    user_id: int
    lat: float
    lng: float
    battery: int = Field(ge=0, le=100)
    incognito: bool = False


class CreateBubbleReq(BaseModel):
    name: str
    icon: int
    color: int
    admin_id: int
    admin_name: str


class JoinBubbleReq(BaseModel):
    code: str
    user_id: int
    name: str


class RecordingMetadata(BaseModel):
    id: str
    user_id: int
    started_at: str
    ended_at: str
    duration_seconds: int
    start_location: Dict[str, str]
    end_location: Dict[str, str]
    files: Dict[str, str]
    uploaded_at: str
