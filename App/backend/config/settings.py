import os
from pathlib import Path
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")

# Database
MONGO_URL = os.getenv("MONGO_URL", "mongodb://localhost:27017")
DATABASE_NAME = "shesafe"
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
WHISPER_MODEL = os.getenv("WHISPER_MODEL", "base")
FCM_SERVER_KEY = os.getenv("FCM_SERVER_KEY", "")
SMS_PROVIDER_URL = os.getenv("SMS_PROVIDER_URL", "")
SMS_PROVIDER_API_KEY = os.getenv("SMS_PROVIDER_API_KEY", "")

# ML Models
BASE_DIR = Path(__file__).resolve().parent.parent
MODELS_DIR = BASE_DIR / "models"
DATA_DIR = BASE_DIR.parent / "data"

GEO_SAFETY_MODEL_PATH = str(MODELS_DIR / "geo_safety_model.pkl")
GEO_SCALER_PATH = str(MODELS_DIR / "geo_scaler.pkl")
DATA_CSV_PATH = str(DATA_DIR / "data 2.csv")
THREAT_DATASET_PATH = str(DATA_DIR / "threat_dataset.csv")
TEXT_CLASSIFIER_MODEL_PATH = str(MODELS_DIR / "text_threat_classifier.pkl")

# Audio Configuration
AUDIO_CONFIG = {
    "CHANNELS": 1,
    "SAMPLE_WIDTH": 2,  # 16-bit PCM
    "SAMPLE_RATE": 16000,
    "SAVE_INTERVAL": 10,  # Save every 10 seconds
}

# Upload Directories
UPLOADS_DIR = BASE_DIR / "uploads"
AUDIO_CHUNKS_DIR = BASE_DIR / "audio_chunks"
ANONYMOUS_RECORDINGS_DIR = UPLOADS_DIR / "anonymous_recordings"
FAKECALL_RECORDINGS_DIR = UPLOADS_DIR / "fakecall_recordings"
NORMAL_RECORDINGS_DIR = UPLOADS_DIR / "recordings"

# Create directories if they don't exist
for directory in [AUDIO_CHUNKS_DIR, ANONYMOUS_RECORDINGS_DIR, FAKECALL_RECORDINGS_DIR, NORMAL_RECORDINGS_DIR]:
    directory.mkdir(parents=True, exist_ok=True)

MODELS_DIR.mkdir(parents=True, exist_ok=True)

# Constants
EARTH_RADIUS = 6371  # km
