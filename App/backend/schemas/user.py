from pydantic import BaseModel
from typing import List, Literal
from datetime import date

class User(BaseModel):
    id: int
    username: str = ""
    email: str
    phone: str
    emergency_contacts: List[str] = []
    gender: Literal["male", "female"]
    birthdate: date
    face_image: str
    aadhar_verified: bool = False
    is_premium: bool = False

class LoginRequest(BaseModel):
    email: str
    password: str

class RegisterRequest(BaseModel):
    username: str = ""
    email: str
    phone: str
    password: str
    gender: Literal["male", "female"]
    birthdate: date
    face_image: str
    aadhar_verified: bool = False
    emergency_contacts: List[str] = []
    is_premium: bool = False


class ForgotPasswordRequest(BaseModel):
    email: str

class LoginResponse(BaseModel):
    success: bool
    user: User
    token: str

class RegisterResponse(BaseModel):
    success: bool
    user: User
    token: str
