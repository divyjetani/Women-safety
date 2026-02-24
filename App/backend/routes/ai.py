from fastapi import APIRouter, HTTPException
from schemas.ai import AskAIRequest, AskAIResponse
from services.ai_service import AIService

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
