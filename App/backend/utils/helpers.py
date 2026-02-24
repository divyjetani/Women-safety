import random
import string
from datetime import datetime, timezone

# random alpha numeric code
def generate_code(length: int = 6) -> str:
    return ''.join(random.choices(string.ascii_uppercase, k=length))

# get iso time
def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

# current time
def now_local_iso() -> str:
    return datetime.now().isoformat()
