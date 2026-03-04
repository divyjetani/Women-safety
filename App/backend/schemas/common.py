# App/backend/schemas/common.py
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
from enum import Enum


class LocationRequest(BaseModel):
    latitude: float
    longitude: float


class StatusEnum(str, Enum):
    ACTIVE = "Active"
    PENDING = "Pending"
    INACTIVE = "Inactive"


class ThreatLevelEnum(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
