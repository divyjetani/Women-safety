from pydantic import BaseModel, EmailStr
from typing import List, Optional
from datetime import datetime

class User(BaseModel):
    id: int
    username: str
    email: str
    phone: str
    emergency_contacts: List[str] = []
    is_premium: bool = False

class LoginRequest(BaseModel):
    phone: str

class RegisterRequest(BaseModel):
    id: int
    username: str
    email: str
    phone: str
    emergency_contacts: List[str] = []
    is_premium: bool = False

class LoginResponse(BaseModel):
    success: bool
    user: User
    token: str

class RegisterResponse(BaseModel):
    success: bool
    user: User
    token: str
