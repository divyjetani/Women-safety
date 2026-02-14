import asyncio, websockets

async def test():
    async with websockets.connect("ws://localhost:8000/ws") as ws:
        print("CONNECTED")
        await ws.send("hello")

asyncio.run(test())
