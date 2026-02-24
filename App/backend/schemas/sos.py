from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class SOSRequest(BaseModel):
    user_id: int
    location: str
    message: Optional[str] = None
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
