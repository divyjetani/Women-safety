import asyncio
import json

import websockets


async def main():
    uri = "ws://127.0.0.1:8001/ws"
    async with websockets.connect(uri) as ws:
        for _ in range(3):
            await ws.send(json.dumps({"type": "proximity", "value": 1.0}))
        msg = await asyncio.wait_for(ws.recv(), timeout=8)
        print(msg)


if __name__ == "__main__":
    asyncio.run(main())
