import json
import struct
import asyncio
import time
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from utils.logger import logger
from utils.audio import save_wav
from config.settings import AUDIO_CHUNKS_DIR, AUDIO_CONFIG

router = APIRouter(tags=["websocket"])


@router.websocket("/ws")
async def websocket_endpoint(ws: WebSocket):
    await ws.accept()
    logger.info("🟢 Client connected")

    audio_buffer: list = []
    buffer_lock = asyncio.Lock()
    threat_score = 0
    running = True

    async def periodic_saver():
        nonlocal running
        save_interval = AUDIO_CONFIG["SAVE_INTERVAL"]
        
        while running:
            await asyncio.sleep(save_interval)

            async with buffer_lock:
                if not audio_buffer:
                    continue

                chunk = audio_buffer.copy()
                audio_buffer.clear()

            filename = str(AUDIO_CHUNKS_DIR / f"audio_{int(time.time())}.wav")
            save_wav(filename, chunk)

            duration = len(chunk) / AUDIO_CONFIG["SAMPLE_RATE"]
            logger.info(f"💾 Saved chunk | duration={duration:.2f}s")

    saver_task = asyncio.create_task(periodic_saver())

    try:
        while True:
            msg = await ws.receive()
            if msg["type"] == "websocket.disconnect":
                logger.warning("🔴 Client disconnected")
                break

            if msg.get("bytes") is not None:
                b = msg["bytes"]
                sample_count = len(b) // 2

                samples = struct.unpack(
                    "<" + "h" * sample_count,
                    b
                )

                async with buffer_lock:
                    audio_buffer.extend(samples)

                continue

            if msg.get("text") is not None:
                try:
                    payload = json.loads(msg["text"])
                except Exception:
                    continue

                if payload.get("type") == "proximity":
                    value = payload.get("value", 0)
                    if value < 2.0:
                        threat_score += 1

                if threat_score >= 3:
                    await ws.send_json(
                        {
                            "threat": True,
                            "confidence": threat_score
                        }
                    )
                    threat_score = 0

    except WebSocketDisconnect:
        logger.warning("🔴 WebSocketDisconnect")

    except Exception as e:
        logger.exception(f"❌ WS error: {e}")

    finally:
        running = False
        saver_task.cancel()
        try:
            await saver_task
        except asyncio.CancelledError:
            pass

        async with buffer_lock:
            if audio_buffer:
                filename = str(AUDIO_CHUNKS_DIR / f"audio_{int(time.time())}_final.wav")
                save_wav(filename, audio_buffer)

                duration = len(audio_buffer) / AUDIO_CONFIG["SAMPLE_RATE"]
                logger.info(f"💾 Final flush saved | duration={duration:.2f}s")

        logger.info("🛑 WS connection fully closed")
