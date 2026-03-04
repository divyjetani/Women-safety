# App/backend/utils/profile_image.py
import base64
import binascii
from pathlib import Path
from typing import Optional
from uuid import uuid4


BACKEND_ROOT = Path(__file__).resolve().parent.parent
PROFILE_PICS_DIR = BACKEND_ROOT / "profile_pics"
PROFILE_PICS_DIR.mkdir(parents=True, exist_ok=True)


def _normalize_input(value: str) -> str:
    raw = (value or "").strip()
    if "," in raw and raw.lower().startswith("data:image"):
        raw = raw.split(",", 1)[1]
    return raw.strip()


def _to_url_path(file_path: Path) -> str:
    return f"/profile_pics/{file_path.name}"


def _is_profile_pic_path(value: str) -> bool:
    normalized = (value or "").replace("\\", "/").strip()
    return normalized.startswith("/profile_pics/") or normalized.startswith("profile_pics/")


def _resolve_existing_file(path_value: Optional[str]) -> Optional[Path]:
    if not path_value:
        return None
    normalized = path_value.replace("\\", "/").strip()
    if normalized.startswith("/profile_pics/"):
        filename = normalized.split("/profile_pics/", 1)[1]
    elif normalized.startswith("profile_pics/"):
        filename = normalized.split("profile_pics/", 1)[1]
    else:
        return None

    candidate = PROFILE_PICS_DIR / filename
    return candidate if candidate.exists() else None


def delete_profile_image(path_value: Optional[str]) -> None:
    existing = _resolve_existing_file(path_value)
    if existing is not None:
        try:
            existing.unlink(missing_ok=True)
        except Exception:
            pass


def persist_profile_image(face_image: str, user_id: int, previous_path: Optional[str] = None) -> str:
    value = (face_image or "").strip()
    if not value:
        if previous_path:
            delete_profile_image(previous_path)
        return ""

    if _is_profile_pic_path(value):
        normalized = value.replace("\\", "/")
        return normalized if normalized.startswith("/") else f"/{normalized}"

    normalized_b64 = _normalize_input(value)

    try:
        image_bytes = base64.b64decode(normalized_b64, validate=True)
    except (binascii.Error, ValueError):
        raise ValueError("Invalid face image format. Expected base64 image string or /profile_pics path.")

    if not image_bytes:
        raise ValueError("Face image is empty after decoding.")

    filename = f"user_{user_id}_{uuid4().hex}.jpg"
    output_path = PROFILE_PICS_DIR / filename
    output_path.write_bytes(image_bytes)

    if previous_path:
        delete_profile_image(previous_path)

    return _to_url_path(output_path)
