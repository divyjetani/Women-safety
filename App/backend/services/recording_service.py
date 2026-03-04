# App/backend/services/recording_service.py
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

    @staticmethod
    def _extract_filename(path_value: str) -> str:
        raw = (path_value or "").strip()
        if not raw:
            return ""
        normalized = raw.replace("\\", "/")
        return normalized.split("/")[-1]

    @staticmethod
    def delete_recording_from_log(
        *,
        log_file: Path,
        media_dir: Path,
        user_id: int,
        recording_id: str,
        file_keys: list[str],
    ) -> dict:
        try:
            if not log_file.exists():
                raise HTTPException(status_code=404, detail="Recording log not found")

            raw_data = json.loads(log_file.read_text(encoding="utf-8"))
            if not isinstance(raw_data, list):
                raw_data = []

            target_record = None
            updated_data = []
            for entry in raw_data:
                if not isinstance(entry, dict):
                    continue

                if str(entry.get("id", "")) == recording_id and int(entry.get("user_id", -1)) == user_id:
                    target_record = entry
                    continue
                updated_data.append(entry)

            if target_record is None:
                raise HTTPException(status_code=404, detail="Recording not found")

            deleted_files = 0
            files = target_record.get("files") or {}
            for file_key in file_keys:
                filename = RecordingService._extract_filename(str(files.get(file_key, "")))
                if not filename:
                    continue
                file_path = media_dir / filename
                if file_path.exists() and file_path.is_file():
                    file_path.unlink(missing_ok=True)
                    deleted_files += 1

            log_file.write_text(json.dumps(updated_data, indent=2), encoding="utf-8")

            return {
                "recording_id": recording_id,
                "deleted_files": deleted_files,
            }
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"❌ Error deleting recording {recording_id}: {e}")
            raise HTTPException(status_code=500, detail=f"Delete failed: {e}")


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

        front_path = ANONYMOUS_RECORDINGS_DIR / f"{unique_id}_front.mp4"
        back_path = ANONYMOUS_RECORDINGS_DIR / f"{unique_id}_back.mp4"
        start_img_path = ANONYMOUS_RECORDINGS_DIR / f"{unique_id}_start.jpg"
        end_img_path = ANONYMOUS_RECORDINGS_DIR / f"{unique_id}_end.jpg"

        await RecordingService.save_uploaded_file(front_video, front_path)
        await RecordingService.save_uploaded_file(back_video, back_path)

        if start_image is not None:
            await RecordingService.save_uploaded_file(start_image, start_img_path)
        if end_image is not None:
            await RecordingService.save_uploaded_file(end_image, end_img_path)

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

        log_file = ANONYMOUS_RECORDINGS_DIR / "anonymous_log.json"
        RecordingService.update_json_log(log_file, new_record)

        return new_record

    @staticmethod
    def delete_anonymous_recording(user_id: int, recording_id: str) -> dict:
        log_file = ANONYMOUS_RECORDINGS_DIR / "anonymous_log.json"
        return RecordingService.delete_recording_from_log(
            log_file=log_file,
            media_dir=ANONYMOUS_RECORDINGS_DIR,
            user_id=user_id,
            recording_id=recording_id,
            file_keys=["front_video", "back_video", "start_image", "end_image"],
        )


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

        video_path = FAKECALL_RECORDINGS_DIR / f"{unique_id}_back.mp4"
        start_img_path = FAKECALL_RECORDINGS_DIR / f"{unique_id}_start.jpg"
        end_img_path = FAKECALL_RECORDINGS_DIR / f"{unique_id}_end.jpg"

        await RecordingService.save_uploaded_file(back_video, video_path)

        if start_image is not None:
            await RecordingService.save_uploaded_file(start_image, start_img_path)
        if end_image is not None:
            await RecordingService.save_uploaded_file(end_image, end_img_path)

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

        log_file = FAKECALL_RECORDINGS_DIR / "recordings_log.json"
        RecordingService.update_json_log(log_file, new_record)

        return new_record

    @staticmethod
    def delete_fakecall_recording(user_id: int, recording_id: str) -> dict:
        log_file = FAKECALL_RECORDINGS_DIR / "recordings_log.json"
        return RecordingService.delete_recording_from_log(
            log_file=log_file,
            media_dir=FAKECALL_RECORDINGS_DIR,
            user_id=user_id,
            recording_id=recording_id,
            file_keys=["back_video", "start_image", "end_image"],
        )
