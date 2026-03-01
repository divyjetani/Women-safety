import json
import shutil
from pathlib import Path
from datetime import datetime
from fastapi import HTTPException, UploadFile
from typing import Optional
from config.settings import ANONYMOUS_RECORDINGS_DIR, FAKECALL_RECORDINGS_DIR
from utils.logger import logger


class RecordingService:
    @staticmethod
    def ensure_directories():
        ANONYMOUS_RECORDINGS_DIR.mkdir(parents=True, exist_ok=True)
        FAKECALL_RECORDINGS_DIR.mkdir(parents=True, exist_ok=True)

    @staticmethod
    async def save_uploaded_file(file: UploadFile, destination: Path) -> None:
        try:
            with destination.open("wb") as buffer:
                shutil.copyfileobj(file.file, buffer)
            logger.info(f"✅ Saved file: {destination}")
        except Exception as e:
            logger.error(f"❌ Error saving file {destination}: {e}")
            raise HTTPException(status_code=500, detail=f"File save failed: {e}")

    # update json on log
    @staticmethod
    def update_json_log(log_file: Path, record: dict) -> None:
        try:
            if not log_file.exists():
                log_file.write_text("[]")
            
            data = json.loads(log_file.read_text())
            data.insert(0, record)
            log_file.write_text(json.dumps(data, indent=2))
            logger.info(f"✅ Updated log: {log_file}")
        except Exception as e:
            logger.error(f"❌ Error updating log {log_file}: {e}")
            raise HTTPException(status_code=500, detail=f"Log update failed: {e}")


class AnonymousRecordingService(RecordingService):
    @staticmethod
    async def upload_anonymous_recording(
        user_id: int,
        started_at: str,
        ended_at: str,
        duration_seconds: int,
        start_lat: str,
        start_lng: str,
        end_lat: str,
        end_lng: str,
        front_video: UploadFile,
        back_video: UploadFile,
        start_image: Optional[UploadFile],
        end_image: Optional[UploadFile],
    ) -> dict:
        RecordingService.ensure_directories()
        
        now = datetime.now().strftime("%Y%m%d_%H%M%S")
        unique_id = f"user{user_id}_{now}"

        # Define file paths
        front_path = ANONYMOUS_RECORDINGS_DIR / f"{unique_id}_front.mp4"
        back_path = ANONYMOUS_RECORDINGS_DIR / f"{unique_id}_back.mp4"
        start_img_path = ANONYMOUS_RECORDINGS_DIR / f"{unique_id}_start.jpg"
        end_img_path = ANONYMOUS_RECORDINGS_DIR / f"{unique_id}_end.jpg"

        # Save required files
        await RecordingService.save_uploaded_file(front_video, front_path)
        await RecordingService.save_uploaded_file(back_video, back_path)

        # Save optional images
        if start_image is not None:
            await RecordingService.save_uploaded_file(start_image, start_img_path)
        if end_image is not None:
            await RecordingService.save_uploaded_file(end_image, end_img_path)

        # Create metadata record
        new_record = {
            "id": unique_id,
            "user_id": user_id,
            "started_at": started_at,
            "ended_at": ended_at,
            "duration_seconds": duration_seconds,
            "start_location": {"lat": start_lat, "lng": start_lng},
            "end_location": {"lat": end_lat, "lng": end_lng},
            "files": {
                "front_video": str(front_path),
                "back_video": str(back_path),
                "start_image": str(start_img_path) if start_image is not None else "",
                "end_image": str(end_img_path) if end_image is not None else "",
            },
            "uploaded_at": datetime.now().isoformat(),
        }

        # Update JSON log
        log_file = ANONYMOUS_RECORDINGS_DIR / "anonymous_log.json"
        RecordingService.update_json_log(log_file, new_record)

        return new_record


class FakecallRecordingService(RecordingService):
    @staticmethod
    async def upload_fakecall_recording(
        user_id: int,
        started_at: str,
        ended_at: str,
        duration_seconds: int,
        start_lat: str,
        start_lng: str,
        end_lat: str,
        end_lng: str,
        back_video: UploadFile,
        start_image: Optional[UploadFile],
        end_image: Optional[UploadFile],
    ) -> dict:
        RecordingService.ensure_directories()
        
        now = datetime.now().strftime("%Y%m%d_%H%M%S")
        unique_id = f"user{user_id}_{now}"

        # Define file paths
        video_path = FAKECALL_RECORDINGS_DIR / f"{unique_id}_back.mp4"
        start_img_path = FAKECALL_RECORDINGS_DIR / f"{unique_id}_start.jpg"
        end_img_path = FAKECALL_RECORDINGS_DIR / f"{unique_id}_end.jpg"

        # Save required file
        await RecordingService.save_uploaded_file(back_video, video_path)

        # Save optional images
        if start_image is not None:
            await RecordingService.save_uploaded_file(start_image, start_img_path)
        if end_image is not None:
            await RecordingService.save_uploaded_file(end_image, end_img_path)

        # Create metadata record
        new_record = {
            "id": unique_id,
            "user_id": user_id,
            "started_at": started_at,
            "ended_at": ended_at,
            "duration_seconds": duration_seconds,
            "start_location": {"lat": start_lat, "lng": start_lng},
            "end_location": {"lat": end_lat, "lng": end_lng},
            "files": {
                "back_video": str(video_path),
                "start_image": str(start_img_path) if start_image is not None else "",
                "end_image": str(end_img_path) if end_image is not None else "",
            },
            "uploaded_at": datetime.now().isoformat(),
        }

        # Update JSON log
        log_file = FAKECALL_RECORDINGS_DIR / "recordings_log.json"
        RecordingService.update_json_log(log_file, new_record)

        return new_record
