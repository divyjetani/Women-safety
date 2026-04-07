# She Safe

## Overview
She Safe is a comprehensive women safety application designed to provide real-time protection, emergency response, and safety analytics. The app empowers users with AI-powered threat detection, location-based safety scoring, instant SOS alerts, and community features for enhanced security.

## Features

### 🔐 Authentication & User Management
- User registration and login with secure password hashing
- Profile management with image upload capabilities
- Password reset functionality
- Persistent server URL settings across app sessions

### 🚨 SOS Emergency System
- One-tap SOS activation with automatic 13-second countdown
- Real-time media capture (front/back camera images, 10-second audio)
- Automatic alert dispatch to emergency contacts via FCM notifications
- SMS fallback for critical alerts
- SOS event tracking and resolution

### 🎙️ Real-Time Audio Processing
- Live audio transcription using OpenAI Whisper
- Real-time threat detection in audio streams
- Audio chunk processing and storage
- WebSocket-based real-time communication

### 🤖 AI-Powered Safety Assistant
- Gemini AI integration for safety-related queries
- Contextual safety suggestions and advice
- Detailed responses with practical steps
- Safety-focused question answering

### 📍 Location-Based Safety
- Dynamic safety scoring based on geographical location
- Machine learning model trained on crime data, police proximity, and crowd density
- Real-time risk assessment
- Nearest police station locator with distance calculation

### 👥 Community & Groups
- Group creation and management for safety networks
- Temporary "bubbles" for ad-hoc safety groups
- Location sharing within groups via WebSocket
- Member management and invitations

### 📊 Analytics & Insights
- Comprehensive safety analytics dashboard
- Alert history and patterns
- Threat report analysis
- Audio session analytics with threat scoring

### 🛡️ Threat Detection & Reporting
- Text-based threat classification using ML models
- Anonymous threat reporting system
- Threat level assessment (high/medium/low)
- Historical threat data analysis

### 📱 Recordings & Media
- Anonymous audio recordings for safety documentation
- Fake call recordings for emergency simulation
- SOS media storage and retrieval
- Secure file upload and management

### 🔔 Notifications
- Push notifications via Firebase Cloud Messaging (FCM)
- In-app notification management
- Alert history and status tracking

### 🔍 Additional Features
- Quick actions for rapid safety responses
- Guardian history tracking
- Help and support system
- Home statistics and safety metrics

## Tech Stack

### Backend
- **Framework**: FastAPI (Python async web framework)
- **Database**: MongoDB with Motor (async MongoDB driver)
- **Authentication**: Passlib with bcrypt for password hashing, Python-JOSE for JWT
- **Real-time Communication**: WebSockets for live audio and location sharing
- **File Handling**: Aiofiles, python-multipart for media uploads
- **API Integrations**: Google Gemini AI, Firebase Cloud Messaging, SMS providers

### Machine Learning & AI
- **Audio Processing**: OpenAI Whisper for speech-to-text
- **Threat Classification**: Scikit-learn models (Gradient Boosting, text classifiers)
- **Data Processing**: Pandas, NumPy for data manipulation
- **Model Serialization**: Joblib for ML model persistence
- **Safety Scoring**: Location-based ML model with geographical features

### Infrastructure
- **Environment Management**: python-dotenv for configuration
- **Logging**: Custom logging utility
- **Static Files**: FastAPI static file serving for media assets
- **CORS**: Custom CORS middleware for cross-origin requests

### Data & Models
- **Training Data**: CSV datasets for crime areas, police stations, crowd density
- **ML Models**: Pre-trained safety scoring and threat classification models
- **Audio Config**: 16kHz mono WAV processing for Whisper compatibility

## Project Structure

```
App/
├── backend/
│   ├── main.py                 # FastAPI application entry point
│   ├── requirements.txt        # Python dependencies
│   ├── config/
│   │   └── settings.py         # Application configuration
│   ├── database/
│   │   ├── db.py              # MongoDB connection management
│   │   ├── collections.py     # Database collection definitions
│   │   └── seed.py            # Database seeding scripts
│   ├── middleware/
│   │   └── cors.py            # CORS middleware
│   ├── models/                 # Pydantic models (if any)
│   ├── routes/                 # API route handlers
│   │   ├── auth.py            # Authentication endpoints
│   │   ├── sos.py             # SOS emergency system
│   │   ├── ai.py              # AI assistant endpoints
│   │   ├── safety_score.py    # Safety scoring
│   │   ├── recordings.py      # Audio recording management
│   │   ├── groups.py          # Group management
│   │   ├── bubble.py          # Temporary safety bubbles
│   │   ├── analytics.py       # Analytics dashboard
│   │   ├── notifications.py   # Notification management
│   │   ├── threat_reports.py  # Threat reporting
│   │   ├── police_stations.py # Police station locator
│   │   ├── websocket.py       # Real-time WebSocket handlers
│   │   └── ...
│   ├── services/              # Business logic services
│   │   ├── ai_service.py      # Gemini AI integration
│   │   ├── safety_service.py  # Safety scoring service
│   │   ├── text_threat_classifier.py # ML text classification
│   │   ├── whisper_client.py  # Audio transcription
│   │   ├── alert_dispatch_service.py # Notification dispatch
│   │   └── recording_service.py # Recording management
│   ├── utils/                 # Utility functions
│   │   ├── audio.py           # Audio processing utilities
│   │   ├── helpers.py         # General helpers
│   │   ├── logger.py          # Logging configuration
│   │   ├── profile_image.py   # Image handling
│   │   └── sos_media.py       # SOS media utilities
│   ├── schemas/               # Pydantic schemas
│   ├── uploads/               # User uploaded files
│   ├── audio_chunks/          # Temporary audio processing
│   └── models/                # ML model files
├── frontend/
│   ├── mobile/                # Flutter mobile application
│   └── web/                   # React web application (Vite)
└── data/                      # Training datasets and processed data
```

## Installation & Setup

### Prerequisites
- Python 3.8+
- MongoDB
- Node.js (for web frontend)
- Flutter (for mobile frontend)

### Backend Setup
1. Navigate to the backend directory:
   ```bash
   cd App/backend
   ```

2. Create a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   # Motor 3.3.2 requires PyMongo 4.5.x; if conflict occurs, force:
   python -m pip install "pymongo==4.5.0" "dnspython==2.8.0"
   ```

4. Set up environment variables in `.env`:
   ```
   # Local MongoDB (fallback)
   MONGO_URL=mongodb://localhost:27017
   DATABASE_NAME=shesafe

   # Mongo Atlas (recommended)
   # MONGO_URL=mongodb+srv://<atlas_user>:<atlas_password>@<atlas_cluster>.mongodb.net/shesafe?retryWrites=true&w=majority
   # DATABASE_NAME=shesafe

   GEMINI_API_KEY=your_gemini_api_key
   FCM_SERVER_KEY=your_fcm_server_key
   WHISPER_MODEL=base
   ```

5. Run the application:
   ```bash
   uvicorn main:app --reload
   ```

### Database Setup
1. Ensure MongoDB is running
2. The application will automatically create collections on first run
3. Run the seed script if needed:
   ```python
   python -m database.seed
   ```

### ML Models
- Place pre-trained ML models in `App/backend/models/`
- Required models: `geo_safety_model.pkl`, `geo_scaler.pkl`, `text_threat_classifier.pkl`

## API Documentation

Once the backend is running, visit `http://localhost:8000/docs` for interactive API documentation powered by Swagger UI.

## Key Endpoints

- `POST /auth/login` - User authentication
- `POST /sos` - Trigger SOS alert
- `POST /ai/ask` - Query AI assistant
- `POST /safety-score` - Get location safety score
- `GET /analytics/overview` - Get user analytics
- `WS /ws/audio` - Real-time audio processing WebSocket

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

For questions or support, please contact the development team.

