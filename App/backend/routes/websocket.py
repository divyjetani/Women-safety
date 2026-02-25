import json
import struct
import asyncio
import time
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from utils.logger import logger
from utils.audio import save_wav
from config.settings import AUDIO_CHUNKS_DIR, AUDIO_CONFIG
from database.collections import get_collections

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

@router.websocket("/ws")
async def websocket_endpoint(ws: WebSocket):
    """Legacy audio processing WebSocket"""
    await ws.accept()
    logger.info("🟢 Client connected to audio WS")

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
        logger.warning("🔴 WebSocketDisconnect from audio WS")

    except Exception as e:
        logger.exception(f"❌ Audio WS error: {e}")

    finally:
        running = False
        saver_task.cancel()
        try:
            await saver_task
        except asyncio.CancelledError:
            pass

        async with buffer_lock:
            if audio_buffer:
                filename = str(AUDIO_CHUNKS_DIR / f"audio_{int(time.time())}.wav")
                save_wav(filename, audio_buffer)
                filename = str(AUDIO_CHUNKS_DIR / f"audio_{int(time.time())}_final.wav")
                save_wav(filename, audio_buffer)

                duration = len(audio_buffer) / AUDIO_CONFIG["SAMPLE_RATE"]
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
