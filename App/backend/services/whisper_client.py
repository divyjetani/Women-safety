from __future__ import annotations

import asyncio
import threading
from pathlib import Path

from config.settings import WHISPER_MODEL
from utils.logger import logger


_whisper_model = None
_model_lock = threading.Lock()
_whisper_unavailable = False


def _prime_torch_runtime() -> None:
    global _whisper_unavailable

    if _whisper_unavailable:
        return

    try:
        import torch  # noqa: F401
    except Exception as exc:
        if _is_windows_torch_dll_error(exc):
            _whisper_unavailable = True
        logger.error(f"❌ Failed to initialize PyTorch runtime for Whisper: {exc}")


def _is_windows_torch_dll_error(exc: Exception) -> bool:
    message = str(exc)
    return "WinError 1114" in message or "c10.dll" in message


def _mark_whisper_unavailable_from_runtime_error(exc: Exception) -> None:
    global _whisper_unavailable

    if _is_windows_torch_dll_error(exc):
        _whisper_unavailable = True
        logger.error("❌ Local Whisper unavailable: PyTorch DLL initialization failed on Windows")
        logger.error(
            "🛠️ Reinstall CPU torch in this interpreter: python -m pip uninstall -y torch torchvision torchaudio && python -m pip install --index-url https://download.pytorch.org/whl/cpu torch torchvision torchaudio"
        )


def prewarm_whisper_runtime() -> None:
    _prime_torch_runtime()


def _resolve_model_name() -> str:
    model_name = (WHISPER_MODEL or "base").strip()
    if model_name == "whisper-1":
        return "base"
    return model_name


def _get_model():
    global _whisper_model, _whisper_unavailable

    if _whisper_unavailable:
        return None

    if _whisper_model is None:
        with _model_lock:
            if _whisper_model is None:
                model_name = _resolve_model_name()
                logger.info(f"🎙️ Loading local Whisper model: {model_name}")
                try:
                    import whisper
                except ModuleNotFoundError:
                    _whisper_unavailable = True
                    logger.error("❌ Missing Whisper dependency: No module named 'whisper'")
                    logger.error("🛠️ Install it in the active backend environment: pip install openai-whisper")
                    return None
                try:
                    _whisper_model = whisper.load_model(model_name)
                except OSError as exc:
                    _whisper_unavailable = True
                    if _is_windows_torch_dll_error(exc):
                        _mark_whisper_unavailable_from_runtime_error(exc)
                    else:
                        logger.error(f"❌ Local Whisper model load failed: {exc}")
                    return None
                except Exception as exc:
                    _whisper_unavailable = True
                    logger.error(f"❌ Local Whisper model load failed: {exc}")
                    return None
    return _whisper_model


def _sync_transcribe(file_path: str) -> str:
    path = Path(file_path)
    if not path.exists():
        return ""

    try:
        model = _get_model()
        if model is None:
            logger.debug(f"Whisper skipped: model unavailable | file={path.name}")
            return ""
        response = model.transcribe(
            str(path),
            fp16=False,
            language="en",
            task="transcribe",
            temperature=0,
        )
        transcript = (response.get("text", "") if isinstance(response, dict) else "").strip()
        logger.debug(
            f"Whisper transcript | file={path.name} | chars={len(transcript)}\n\n"
        )
        return transcript
    except Exception as exc:
        message = str(exc)
        if "cannot reshape tensor of 0 elements" in message:
            logger.warning(f"⚠️ Skipping invalid/empty audio chunk for Whisper: {path.name}\n")
            logger.debug(f"Whisper skipped invalid chunk | file={path.name} | error={exc}")
            return ""
        _mark_whisper_unavailable_from_runtime_error(exc)
        logger.error(f"❌ Local Whisper transcription failed: {exc} \n")
        logger.debug(f"Whisper failed | file={path.name} | error={exc}")
        return ""


async def transcribe_audio_file(file_path: str) -> str:
    return await asyncio.to_thread(_sync_transcribe, file_path)
