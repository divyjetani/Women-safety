import wave
import struct
from pathlib import Path
from typing import List
from utils.logger import logger
from config.settings import AUDIO_CONFIG

# save audio
def save_wav(path: str, samples: List[int]) -> None:
    if not samples:
        logger.warning(f"No samples to save for: {path}")
        return

    try:
        handler = wave.open(path, "wb")
        handler.setnchannels(AUDIO_CONFIG["CHANNELS"])
        handler.setsampwidth(AUDIO_CONFIG["SAMPLE_WIDTH"])
        handler.setframerate(AUDIO_CONFIG["SAMPLE_RATE"])

        pcm_bytes = struct.pack(
            "<" + "h" * len(samples),
            *samples
        )
        handler.writeframes(pcm_bytes)
        handler.close()
        
        logger.info(f"✅ Saved WAV: {path}")
    except Exception as e:
        logger.error(f"❌ Error saving WAV {path}: {e}")

# calc duration of audio
def calculate_duration(sample_count: int) -> float:
    return sample_count / AUDIO_CONFIG["SAMPLE_RATE"]
