# App/backend/utils/sos_media.py
import base64
import hashlib
import shutil
from pathlib import Path
from typing import Optional

from config.settings import BASE_DIR, SOS_MEDIA_DIR, AUDIO_CHUNKS_DIR


def _normalize_base64(value: str) -> tuple[str, str]:
    raw = value.strip()
    if "," in raw and raw.lower().startswith("data:image"):
        header, payload = raw.split(",", 1)
        mime = header.split(";")[0].replace("data:", "").strip().lower()
        ext = ".jpg"
        if mime.endswith("png"):
            ext = ".png"
        elif mime.endswith("webp"):
            ext = ".webp"
        elif mime.endswith("jpeg") or mime.endswith("jpg"):
            ext = ".jpg"
        return payload.strip(), ext
    return raw, ".jpg"


def _copy_known_local_path(source_value: str, output_path: Path) -> Optional[str]:
    source = source_value.strip()
    if not source:
        return None

    if source.startswith("/"):
        candidate = (BASE_DIR / source.lstrip("/")).resolve()
    else:
        candidate = Path(source).expanduser().resolve()

    if not candidate.exists() or not candidate.is_file():
        return None

    output_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(candidate, output_path)
    return f"/sos_media/{output_path.name}"


def persist_sos_image(image_value: Optional[str], user_id: int, event_id: str, kind: str) -> str:
    value = (image_value or "").strip()
    if not value:
        return ""

    if value.startswith("/sos_media/"):
        return value

    file_hash = hashlib.sha1(value.encode("utf-8")).hexdigest()[:10]

    # if image is an existing path (like /profile_pics/...), copy to sos media folder.
    path_ext = Path(value).suffix.lower() if Path(value).suffix else ".jpg"
    if value.startswith("/") or Path(value).exists():
        output_path = SOS_MEDIA_DIR / f"{event_id}_{kind}_{user_id}_{file_hash}{path_ext}"
        copied = _copy_known_local_path(value, output_path)
        if copied:
            return copied

    # otherwise treat as base64 image payload.
    try:
        normalized_b64, ext = _normalize_base64(value)
        image_bytes = base64.b64decode(normalized_b64, validate=True)
        if not image_bytes:
            return ""

        output_path = SOS_MEDIA_DIR / f"{event_id}_{kind}_{user_id}_{file_hash}{ext}"
        output_path.write_bytes(image_bytes)
        return f"/sos_media/{output_path.name}"
    except Exception:
        # fallback: if this was an absolute url or unsupported input, keep as-is.
        return value


def resolve_audio_clip_url(audio_value: Optional[str]) -> str:
    value = (audio_value or "").strip()
    if value.startswith("/audio_chunks/"):
        return value

    if value and not value.startswith("pending://"):
        candidate = Path(value)
        if candidate.exists() and candidate.is_file():
            return f"/audio_chunks/{candidate.name}"
        return value

    # resolve pending/empty value to latest backend audio chunk if available.
    try:
        wav_files = sorted(
            [p for p in AUDIO_CHUNKS_DIR.glob("*.wav") if p.is_file()],
            key=lambda path: path.stat().st_mtime,
            reverse=True,
        )
        if wav_files:
            return f"/audio_chunks/{wav_files[0].name}"
    except Exception:
        pass

    return ""


def persist_sos_audio(audio_value: Optional[str], user_id: int, event_id: str) -> str:
    value = (audio_value or "").strip()
    if not value:
        return resolve_audio_clip_url(value)

    if value.startswith("/sos_media/"):
        return value

    if value.startswith("/audio_chunks/"):
        return value

    file_hash = hashlib.sha1(value.encode("utf-8")).hexdigest()[:10]

    # local file path upload support
    if value.startswith("/") or Path(value).exists():
        path_ext = Path(value).suffix.lower() or ".m4a"
        output_path = SOS_MEDIA_DIR / f"{event_id}_audio_{user_id}_{file_hash}{path_ext}"
        copied = _copy_known_local_path(value, output_path)
        if copied:
            return copied

    # base64 data uri support, e.g. data:audio/mp4;base64,...
    if "," in value and value.lower().startswith("data:audio"):
        try:
            header, payload = value.split(",", 1)
            mime = header.split(";")[0].replace("data:", "").strip().lower()
            ext = ".m4a"
            if "wav" in mime:
                ext = ".wav"
            elif "mpeg" in mime or "mp3" in mime:
                ext = ".mp3"
            elif "ogg" in mime:
                ext = ".ogg"

            audio_bytes = base64.b64decode(payload.strip(), validate=True)
            if not audio_bytes:
                return ""

            output_path = SOS_MEDIA_DIR / f"{event_id}_audio_{user_id}_{file_hash}{ext}"
            output_path.write_bytes(audio_bytes)
            return f"/sos_media/{output_path.name}"
        except Exception:
            return resolve_audio_clip_url(value)

    return resolve_audio_clip_url(value)
