# App/backend/routes/recordings.py
import json
from pathlib import Path

from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from database.collections import get_collections
from config.settings import ANONYMOUS_RECORDINGS_DIR, FAKECALL_RECORDINGS_DIR
from services.recording_service import (
    AnonymousRecordingService,
    FakecallRecordingService,
)

router = APIRouter(prefix="/recordings", tags=["recordings"])


def _load_log_file(log_file: Path) -> list[dict]:
    if not log_file.exists():
        return []
    try:
        data = json.loads(log_file.read_text(encoding="utf-8"))
        if isinstance(data, list):
            return [entry for entry in data if isinstance(entry, dict)]
    except Exception:
        return []
    return []


def _filename_from_path(path_value: str) -> str:
    if not path_value:
        return ""
    normalized = str(path_value).replace("\\", "/")
    return normalized.split("/")[-1]


def _media_payload(path_value: str, public_prefix: str, directory: Path) -> dict:
    filename = _filename_from_path(path_value)
    if not filename:
        return {"path": "", "url": "", "exists": False}

    local_path = directory / filename
    exists = local_path.exists()
    return {
        "path": str(path_value),
        "url": f"{public_prefix}/{filename}" if exists else "",
        "exists": exists,
    }


async def _ensure_allowed_user(user_id: int) -> None:
    users_col = get_collections()["users"]
    user = await users_col.find_one({"id": user_id}, {"_id": 0, "gender": 1})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    gender = str(user.get("gender", "")).strip().lower()
    if gender == "male":
        raise HTTPException(
            status_code=403,
            detail="This feature is not available for male users.",
        )


@router.post("/upload-anonymous")
async def upload_anonymous_recording(
    user_id: int = Form(...),
    started_at: str = Form(...),
    ended_at: str = Form(...),
    duration_seconds: int = Form(...),
    start_lat: str = Form(""),
    start_lng: str = Form(""),
    end_lat: str = Form(""),
    end_lng: str = Form(""),
    front_video: UploadFile = File(...),
    back_video: UploadFile = File(...),
    start_image: UploadFile | None = File(default=None),
    end_image: UploadFile | None = File(default=None),
):
    try:
        await _ensure_allowed_user(user_id)
        recording = await AnonymousRecordingService.upload_anonymous_recording(
            user_id=user_id,
            started_at=started_at,
            ended_at=ended_at,
            duration_seconds=duration_seconds,
            start_lat=start_lat,
            start_lng=start_lng,
            end_lat=end_lat,
            end_lng=end_lng,
            front_video=front_video,
            back_video=back_video,
            start_image=start_image,
            end_image=end_image,
        )
        
        return {
            "success": True,
            "message": "Anonymous recording uploaded successfully ✅",
            "recording": recording,
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload failed: {e}")


@router.post("/upload-fakecall")
async def upload_fakecall_recording(
    user_id: int = Form(...),
    started_at: str = Form(...),
    ended_at: str = Form(...),
    duration_seconds: int = Form(...),
    start_lat: str = Form(""),
    start_lng: str = Form(""),
    end_lat: str = Form(""),
    end_lng: str = Form(""),
    back_video: UploadFile = File(...),
    start_image: UploadFile | None = File(default=None),
    end_image: UploadFile | None = File(default=None),
):
    try:
        await _ensure_allowed_user(user_id)
        recording = await FakecallRecordingService.upload_fakecall_recording(
            user_id=user_id,
            started_at=started_at,
            ended_at=ended_at,
            duration_seconds=duration_seconds,
            start_lat=start_lat,
            start_lng=start_lng,
            end_lat=end_lat,
            end_lng=end_lng,
            back_video=back_video,
            start_image=start_image,
            end_image=end_image,
        )
        
        return {
            "success": True,
            "message": "Fake call recording uploaded successfully ✅",
            "recording": recording,
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload failed: {e}")


@router.get("/anonymous-history")
async def get_anonymous_history(user_id: int):
    await _ensure_allowed_user(user_id)

    log_file = ANONYMOUS_RECORDINGS_DIR / "anonymous_log.json"
    entries = _load_log_file(log_file)

    history = []
    for entry in entries:
        if entry.get("user_id") != user_id:
            continue

        files = entry.get("files") or {}
        front_media = _media_payload(files.get("front_video", ""), "/anonymous_recordings", ANONYMOUS_RECORDINGS_DIR)
        back_media = _media_payload(files.get("back_video", ""), "/anonymous_recordings", ANONYMOUS_RECORDINGS_DIR)
        start_media = _media_payload(files.get("start_image", ""), "/anonymous_recordings", ANONYMOUS_RECORDINGS_DIR)
        end_media = _media_payload(files.get("end_image", ""), "/anonymous_recordings", ANONYMOUS_RECORDINGS_DIR)

        history.append(
            {
                "id": entry.get("id"),
                "user_id": entry.get("user_id"),
                "started_at": entry.get("started_at", ""),
                "ended_at": entry.get("ended_at", ""),
                "duration_seconds": entry.get("duration_seconds", 0),
                "start_location": entry.get("start_location") or {},
                "end_location": entry.get("end_location") or {},
                "files": {
                    "front_video": front_media,
                    "back_video": back_media,
                    "start_image": start_media,
                    "end_image": end_media,
                },
                "has_video": front_media["exists"] or back_media["exists"],
                "uploaded_at": entry.get("uploaded_at", ""),
            }
        )

    return {"success": True, "history": history}


@router.get("/fakecall-history")
async def get_fakecall_history(user_id: int):
    await _ensure_allowed_user(user_id)

    log_file = FAKECALL_RECORDINGS_DIR / "recordings_log.json"
    entries = _load_log_file(log_file)

    history = []
    for entry in entries:
        if entry.get("user_id") != user_id:
            continue

        files = entry.get("files") or {}
        back_media = _media_payload(files.get("back_video", ""), "/fakecall_recordings", FAKECALL_RECORDINGS_DIR)
        start_media = _media_payload(files.get("start_image", ""), "/fakecall_recordings", FAKECALL_RECORDINGS_DIR)
        end_media = _media_payload(files.get("end_image", ""), "/fakecall_recordings", FAKECALL_RECORDINGS_DIR)

        history.append(
            {
                "id": entry.get("id"),
                "user_id": entry.get("user_id"),
                "started_at": entry.get("started_at", ""),
                "ended_at": entry.get("ended_at", ""),
                "duration_seconds": entry.get("duration_seconds", 0),
                "start_location": entry.get("start_location") or {},
                "end_location": entry.get("end_location") or {},
                "files": {
                    "back_video": back_media,
                    "start_image": start_media,
                    "end_image": end_media,
                },
                "has_video": back_media["exists"],
                "uploaded_at": entry.get("uploaded_at", ""),
            }
        )

    return {"success": True, "history": history}


@router.delete("/anonymous/{recording_id}")
async def delete_anonymous_recording(recording_id: str, user_id: int):
    await _ensure_allowed_user(user_id)
    deleted = AnonymousRecordingService.delete_anonymous_recording(
        user_id=user_id,
        recording_id=recording_id,
    )
    return {
        "success": True,
        "message": "Anonymous recording deleted successfully",
        "deleted": deleted,
    }


@router.delete("/fakecall/{recording_id}")
async def delete_fakecall_recording(recording_id: str, user_id: int):
    await _ensure_allowed_user(user_id)
    deleted = FakecallRecordingService.delete_fakecall_recording(
        user_id=user_id,
        recording_id=recording_id,
    )
    return {
        "success": True,
        "message": "Fake call recording deleted successfully",
        "deleted": deleted,
    }
