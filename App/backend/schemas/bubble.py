# App/backend/schemas/bubble.py
from pydantic import BaseModel
from typing import List
from datetime import datetime

class CreateBubbleRequest(BaseModel):
    name: str
    icon: int
    color: int

class BubbleResponse(BaseModel):
    id: str
    name: str
    icon: int
    color: int
    members: List[int]

class LocationUpdateRequest(BaseModel):
    bubble_id: str
    user_id: int
    latitude: float
    longitude: float
    incognito: bool
