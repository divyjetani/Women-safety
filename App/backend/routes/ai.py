# App/backend/routes/ai.py
from fastapi import APIRouter, HTTPException
from datetime import datetime
from schemas.ai import AskAIRequest, AskAIResponse, GenerateSuggestionsRequest, SuggestionsResponse
from services.ai_service import AIService
from database.collections import get_collections

router = APIRouter(prefix="/ai", tags=["ai"])

ai_service = AIService()

@router.post("/ask", response_model=AskAIResponse)
async def ask_ai(req: AskAIRequest):
    try:
        if not req.question.strip():
            raise HTTPException(status_code=400, detail="Question cannot be empty")

        result = await ai_service.ask_question(
            user_id=req.user_id,
            question=req.question,
            detailed=req.detailed,
        )
        
        if not result.get("success"):
            raise HTTPException(
                status_code=500,
                detail=result.get("error", "AI error")
            )
        
        return result

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI error: {e}")


@router.post("/suggestions/generate", response_model=SuggestionsResponse)
async def generate_ai_suggestions(req: GenerateSuggestionsRequest):
    collections = get_collections()
    users_col = collections["users"]
    sos_events_col = collections["sos_events"]
    home_stats_col = collections["home_stats"]
    audio_analytics_col = collections["audio_session_analytics"]
    ai_suggestions_col = collections["ai_suggestions"]

    user = await users_col.find_one({"id": req.user_id}, {"_id": 0})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    latest_sos = await sos_events_col.find({"user_id": req.user_id}, {"_id": 0}).sort("created_at", -1).to_list(length=20)
    home_stats = await home_stats_col.find_one({"user_id": req.user_id}, {"_id": 0}) or {}
    audio_sessions = await audio_analytics_col.find({"$or": [{"user_id": req.user_id}, {"user_id": None}]}, {"_id": 0}).sort("closed_at", -1).to_list(length=30)

    avg_audio = round(
        sum(float(a.get("avg_audio_score", 0.0) or 0.0) for a in audio_sessions) / len(audio_sessions),
        2,
    ) if audio_sessions else 0.0

    context_payload = {
        "user": {
            "id": req.user_id,
            "is_premium": user.get("is_premium", False),
            "stats": user.get("stats", {}),
        },
        "home_stats": home_stats,
        "recent_sos_count": len(latest_sos),
        "latest_sos_locations": [s.get("location", "") for s in latest_sos[:5]],
        "average_audio_score": avg_audio,
    }

    result = await ai_service.generate_safety_suggestions(context_payload)
    if not result.get("success"):
        raise HTTPException(status_code=500, detail=result.get("error", "Failed to generate suggestions"))

    suggestions = result.get("suggestions", [])
    await ai_suggestions_col.insert_one(
        {
            "user_id": req.user_id,
            "created_at": datetime.utcnow().isoformat(),
            "context": context_payload,
            "suggestions": suggestions,
        }
    )

    return {
        "success": True,
        "suggestions": suggestions,
    }
