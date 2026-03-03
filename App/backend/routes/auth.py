from fastapi import APIRouter, HTTPException
from datetime import datetime
from passlib.context import CryptContext
from passlib.exc import UnknownHashError

try:
    import bcrypt as bcrypt_lib
except Exception:
    bcrypt_lib = None

from schemas.user import LoginRequest, RegisterRequest, ForgotPasswordRequest, ResetPasswordRequest
from database.collections import get_collections
from utils.profile_image import persist_profile_image

router = APIRouter(prefix="/auth", tags=["auth"])
pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")


def _sanitize_user(user_doc: dict) -> dict:
    sanitized = {k: v for k, v in user_doc.items() if k not in {"_id", "password_hash"}}
    return sanitized


def _verify_password_with_fallback(plain_password: str, stored_hash: str) -> tuple[bool, bool]:
    try:
        return pwd_context.verify(plain_password, stored_hash), False
    except UnknownHashError:
        pass

    if stored_hash.startswith(("$2a$", "$2b$", "$2y$")) and bcrypt_lib is not None:
        try:
            ok = bcrypt_lib.checkpw(plain_password.encode("utf-8"), stored_hash.encode("utf-8"))
            return ok, ok
        except Exception:
            return False, False

    if stored_hash == plain_password:
        return True, True

    return False, False

@router.post("/login")
async def login(request: LoginRequest):
    collections = get_collections()
    users_col = collections["users"]

    normalized_email = request.email.strip().lower()
    user = await users_col.find_one({"email": normalized_email})

    if not user:
        raise HTTPException(status_code=404, detail="User not found for this email")

    password_hash = user.get("password_hash", "")
    if not password_hash:
        raise HTTPException(status_code=401, detail="Invalid email or password")

    is_valid, needs_migration = _verify_password_with_fallback(request.password, password_hash)
    if not is_valid:
        raise HTTPException(status_code=401, detail="Invalid email or password")

    if needs_migration:
        migrated_hash = pwd_context.hash(request.password)
        await users_col.update_one(
            {"id": user.get("id")},
            {"$set": {"password_hash": migrated_hash}},
        )
        user["password_hash"] = migrated_hash

    return {
        "success": True,
        "user": _sanitize_user(user),
        "token": f"token_{user.get('id', 0)}_{int(datetime.now().timestamp())}"
    }


@router.post("/register")
async def register(user: RegisterRequest):
    collections = get_collections()
    users_col = collections["users"]

    normalized_email = user.email.strip().lower()
    exists = await users_col.find_one({"$or": [{"phone": user.phone}, {"email": normalized_email}]})
    if exists:
        raise HTTPException(status_code=409, detail="User already exists with this phone/email")

    last_user = await users_col.find_one(sort=[("id", -1)])
    next_id = (last_user.get("id", 0) if last_user else 0) + 1

    try:
        face_image_path = persist_profile_image(user.face_image, user_id=next_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    username = user.username.strip() if user.username else normalized_email.split("@")[0]

    doc = {
        "id": next_id,
        "username": username,
        "email": normalized_email,
        "phone": user.phone,
        "password_hash": pwd_context.hash(user.password),
        "gender": user.gender,
        "birthdate": user.birthdate.isoformat(),
        "face_image": face_image_path,
        "aadhar_verified": user.aadhar_verified,
        "emergency_contacts": user.emergency_contacts,
        "is_premium": user.is_premium,
        "created_at": datetime.utcnow().isoformat(),
        "stats": {
            "safeDays": 1,
            "sosUsed": 0,
            "checkins": 0,
            "guardians": len(user.emergency_contacts),
        },
        "settings": {
            "notifications": True,
            "locationSharing": True,
        },
    }

    await users_col.insert_one(doc)

    return {
        "success": True,
        "user": _sanitize_user(doc),
        "token": f"token_{next_id}_{int(datetime.now().timestamp())}"
    }


@router.post("/forgot-password")
async def forgot_password(request: ForgotPasswordRequest):
    collections = get_collections()
    users_col = collections["users"]

    normalized_email = request.email.strip().lower()
    user = await users_col.find_one({"email": normalized_email})

    if not user:
        raise HTTPException(status_code=404, detail="User not found for this email")

    return {
        "success": True,
        "message": "Email verified. Enter a new password to reset.",
    }


@router.post("/reset-password")
async def reset_password(request: ResetPasswordRequest):
    collections = get_collections()
    users_col = collections["users"]

    normalized_email = request.email.strip().lower()
    user = await users_col.find_one({"email": normalized_email})
    if not user:
        raise HTTPException(status_code=404, detail="User not found for this email")

    new_password = request.new_password.strip()
    confirm_password = request.confirm_password.strip()

    if len(new_password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")

    if new_password != confirm_password:
        raise HTTPException(status_code=400, detail="Passwords do not match")

    await users_col.update_one(
        {"id": user.get("id")},
        {"$set": {"password_hash": pwd_context.hash(new_password)}},
    )

    return {
        "success": True,
        "message": "Password reset successful",
    }
