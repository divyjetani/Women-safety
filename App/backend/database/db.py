# App/backend/database/db.py
from contextlib import asynccontextmanager
from urllib.parse import parse_qs, urlparse

from motor.motor_asyncio import AsyncIOMotorClient

from config.settings import DATABASE_NAME, MONGO_TLS, MONGO_URL

mongo_client = None
db = None


def _should_enable_tls() -> bool:
    if MONGO_TLS is not None:
        return MONGO_TLS.strip().lower() in {"1", "true", "yes", "on"}

    parsed_url = urlparse(MONGO_URL)
    query = parse_qs(parsed_url.query)

    if parsed_url.scheme == "mongodb+srv":
        return True

    tls_values = query.get("tls") or query.get("ssl")
    if tls_values:
        return tls_values[-1].strip().lower() == "true"

    return False

async def connect_db():
    global mongo_client, db
    mongo_client = AsyncIOMotorClient(MONGO_URL, tls=_should_enable_tls())
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
