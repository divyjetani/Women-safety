# App/backend/database/db.py
from motor.motor_asyncio import AsyncIOMotorClient
from contextlib import asynccontextmanager
from config.settings import MONGO_URL, DATABASE_NAME

mongo_client = None
db = None


async def connect_db():
    global mongo_client, db
    mongo_client = AsyncIOMotorClient(MONGO_URL)
    db = mongo_client[DATABASE_NAME]
    return db


async def close_db():
    if mongo_client:
        mongo_client.close()


def get_db():
    """Get database instance"""
    return db


@asynccontextmanager
async def lifespan_manager(app):
    """Lifespan context manager for FastAPI app."""
    await connect_db()
    
    yield
    
    await close_db()
