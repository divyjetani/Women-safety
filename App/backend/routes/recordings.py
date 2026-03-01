from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from services.recording_service import (
    AnonymousRecordingService,
    FakecallRecordingService,
)

router = APIRouter(prefix="/recordings", tags=["recordings"])


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
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload failed: {e}")
