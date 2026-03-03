import json
import struct
import asyncio
import time
from pathlib import Path
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from utils.logger import logger
from utils.audio import save_wav
from config.settings import AUDIO_CHUNKS_DIR, AUDIO_CONFIG
from database.collections import get_collections
from services.whisper_client import transcribe_audio_file
from services.text_threat_classifier import TextThreatClassifier

router = APIRouter(tags=["websocket"])

# Keep track of active WebSocket connections for location sharing
class ConnectionManager:
    def __init__(self):
        self.active_connections: dict = {}  # {bubble_code: [websocket, ...]}

    async def connect(self, websocket: WebSocket, bubble_code: str, user_id: int):
        await websocket.accept()
        if bubble_code not in self.active_connections:
            self.active_connections[bubble_code] = []
        self.active_connections[bubble_code].append({
            "ws": websocket,
            "user_id": user_id,
            "bubble_code": bubble_code
        })

    def disconnect(self, bubble_code: str, user_id: int):
        if bubble_code in self.active_connections:
            self.active_connections[bubble_code] = [
                conn for conn in self.active_connections[bubble_code]
                if conn["user_id"] != user_id
            ]
            if not self.active_connections[bubble_code]:
                del self.active_connections[bubble_code]

    async def broadcast_location(self, bubble_code: str, location_data: dict):
        """Broadcast location update to all members in bubble"""
        if bubble_code in self.active_connections:
            disconnected = []
            for connection in self.active_connections[bubble_code]:
                try:
                    await connection["ws"].send_json({
                        "type": "location_update",
                        "data": location_data
                    })
                except Exception as e:
                    logger.error(f"Error sending location: {e}")
                    disconnected.append(connection)
            
            # Remove disconnected connections
            for conn in disconnected:
                self.disconnect(bubble_code, conn["user_id"])

manager = ConnectionManager()
text_classifier = TextThreatClassifier()

MAX_SAVED_AUDIO_CHUNKS = 20
MIN_SAVE_SECONDS = 1.0
MIN_TRANSCRIBE_SECONDS = 1.0
AUTO_SOS_CONFIDENCE_THRESHOLD = 0.90


def _safe_delete_audio_file(file_path: str) -> None:
    try:
        path = Path(file_path)
        if path.exists():
            path.unlink()
    except Exception as exc:
        logger.warning(f"⚠️ Failed to delete temp audio file {file_path}: {exc}")


def _prune_audio_chunks(keep: int = MAX_SAVED_AUDIO_CHUNKS) -> None:
    try:
        files = [
            p for p in AUDIO_CHUNKS_DIR.glob("*.wav")
            if p.is_file()
        ]
        files.sort(key=lambda p: p.stat().st_mtime, reverse=True)

        for old_file in files[keep:]:
            old_file.unlink(missing_ok=True)
    except Exception as exc:
        logger.warning(f"⚠️ Failed to prune audio chunks: {exc}")

@router.websocket("/ws")
async def websocket_endpoint(ws: WebSocket):
    """Legacy audio processing WebSocket"""
    await ws.accept()
    logger.info("🟢 Client connected to audio WS")

    audio_buffer: list = []
    buffer_lock = asyncio.Lock()
    threat_score = 0
    running = True
    sample_rate = AUDIO_CONFIG["SAMPLE_RATE"]
    chunk_seconds = 10
    chunk_samples = sample_rate * chunk_seconds
    processing_tasks: set[asyncio.Task] = set()

    async def process_10s_chunk(samples: list[int]):
        duration = len(samples) / sample_rate
        if duration < MIN_TRANSCRIBE_SECONDS:
            logger.info(f"⏭️ Skipping short chunk for transcription | duration={duration:.2f}s")
            return

        filename = str(AUDIO_CHUNKS_DIR / f"audio_{int(time.time() * 1000)}_10s.wav")
        save_wav(filename, samples)
        _prune_audio_chunks()

        transcript = await transcribe_audio_file(filename)
        if not transcript:
            return

        prediction = text_classifier.predict(transcript)
        is_threat = prediction.get("is_threat", False)
        confidence = float(prediction.get("confidence", 0.0))

        logger.info(
            f"📝 Transcript: {transcript[:120]} | threat={is_threat} | confidence={confidence:.2f}"
        )
        print(f"[WS WORDS] {transcript}")

        if is_threat and confidence >= AUTO_SOS_CONFIDENCE_THRESHOLD:
            await ws.send_json(
                {
                    "type": "threat_detected",
                    "threat": True,
                    "auto_sos": True,
                    "confidence": confidence,
                    "transcript": transcript,
                    "reason": "Threatful language detected in 10-second audio chunk",
                }
            )

    async def periodic_saver():
        nonlocal running
        save_interval = AUDIO_CONFIG["SAVE_INTERVAL"]
        
        while running:
            await asyncio.sleep(save_interval)

            async with buffer_lock:
                if not audio_buffer:
                    continue

                chunk = audio_buffer.copy()

            duration = len(chunk) / AUDIO_CONFIG["SAMPLE_RATE"]
            if duration < MIN_SAVE_SECONDS:
                continue

            filename = str(AUDIO_CHUNKS_DIR / f"audio_{int(time.time())}.wav")
            save_wav(filename, chunk)
            _prune_audio_chunks()

            # logger.info(f"💾 Saved chunk | duration={duration:.2f}s")

    saver_task = asyncio.create_task(periodic_saver())

    try:
        while True:
            msg = await ws.receive()
            if msg["type"] == "websocket.disconnect":
                logger.warning("🔴 Client disconnected from audio WS")
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

                    while len(audio_buffer) >= chunk_samples:
                        chunk = audio_buffer[:chunk_samples]
                        del audio_buffer[:chunk_samples]

                        task = asyncio.create_task(process_10s_chunk(chunk))
                        processing_tasks.add(task)
                        task.add_done_callback(processing_tasks.discard)

                continue

            if msg.get("text") is not None:
                try:
                    payload = json.loads(msg["text"])
                except Exception:
                    continue

                if payload.get("type") == "audio" and isinstance(payload.get("data"), list):
                    try:
                        parsed_samples = [int(v) for v in payload["data"]]
                    except Exception:
                        parsed_samples = []

                    if parsed_samples:
                        async with buffer_lock:
                            audio_buffer.extend(parsed_samples)

                            while len(audio_buffer) >= chunk_samples:
                                chunk = audio_buffer[:chunk_samples]
                                del audio_buffer[:chunk_samples]

                                task = asyncio.create_task(process_10s_chunk(chunk))
                                processing_tasks.add(task)
                                task.add_done_callback(processing_tasks.discard)
                    continue

                if payload.get("type") == "proximity":
                    value = payload.get("value", 0)
                    if value < 2.0:
                        threat_score += 1

                if threat_score >= 3:
                    await ws.send_json(
                        {
                            "type": "proximity_threat",
                            "threat": True,
                            "confidence": threat_score
                        }
                    )
                    threat_score = 0

    except WebSocketDisconnect:
        logger.warning("🔴 WebSocketDisconnect from audio WS")

    except Exception as e:
        logger.exception(f"❌ Audio WS error: {e}")

    finally:
        running = False
        saver_task.cancel()
        for task in list(processing_tasks):
            task.cancel()
        try:
            await saver_task
        except asyncio.CancelledError:
            pass

        async with buffer_lock:
            if audio_buffer:
                duration = len(audio_buffer) / AUDIO_CONFIG["SAMPLE_RATE"]
                if duration >= MIN_SAVE_SECONDS:
                    final_filename = str(AUDIO_CHUNKS_DIR / f"audio_{int(time.time())}_final.wav")
                    save_wav(final_filename, audio_buffer)
                    _prune_audio_chunks()
                    logger.info(f"💾 Final flush saved | duration={duration:.2f}s")

        logger.info("🛑 WS connection fully closed")


@router.websocket("/ws/bubble/{bubble_code}/{user_id}")
async def bubble_location_websocket(ws: WebSocket, bubble_code: str, user_id: int):
    """
    WebSocket for real-time location sharing within bubbles.
    Client sends location updates, server broadcasts to all bubble members.
    """
    try:
        await manager.connect(ws, bubble_code, user_id)
        logger.info(f"🟢 User {user_id} connected to bubble {bubble_code}")
        
        # Get bubble info from database
        collections = get_collections()
        bubbles_col = collections["bubbles"]
        bubble = await bubbles_col.find_one({"code": bubble_code})
        
        if not bubble:
            await ws.send_json({"error": "Bubble not found"})
            await ws.close()
            return
        
        # Send initial bubble members info
        await ws.send_json({
            "type": "bubble_info",
            "bubble": {
                "code": bubble_code,
                "name": bubble.get("name"),
                "members": bubble.get("members", [])
            }
        })
        
        while True:
            data = await ws.receive_json()
            
            if data.get("type") == "location_update":
                # Update user location in database
                await bubbles_col.update_one(
                    {"code": bubble_code, "members.user_id": user_id},
                    {
                        "$set": {
                            "members.$.lat": data.get("lat"),
                            "members.$.lng": data.get("lng"),
                            "members.$.battery": data.get("battery", 100),
                            "members.$.last_updated": time.time()
                        }
                    }
                )
                
                # Get updated bubble
                updated_bubble = await bubbles_col.find_one({"code": bubble_code})
                
                # Broadcast to all members
                await manager.broadcast_location(bubble_code, {
                    "user_id": user_id,
                    "lat": data.get("lat"),
                    "lng": data.get("lng"),
                    "battery": data.get("battery"),
                    "members": updated_bubble.get("members", [])
                })
                
                # Removed verbose logging - too noisy with 5-second updates
            
            elif data.get("type") == "ping":
                await ws.send_json({"type": "pong"})
    
    except WebSocketDisconnect:
        logger.warning(f"🔴 User {user_id} disconnected from bubble {bubble_code}")
        manager.disconnect(bubble_code, user_id)
    
    except Exception as e:
        logger.exception(f"❌ Bubble WS error: {e}")
        manager.disconnect(bubble_code, user_id)
