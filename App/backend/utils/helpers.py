# App/backend/utils/helpers.py
import random
import string
from datetime import datetime, timezone

def generate_code(length: int = 6) -> str:
    return ''.join(random.choices(string.ascii_uppercase, k=length))

def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

def now_local_iso() -> str:
    return datetime.now().isoformat()
