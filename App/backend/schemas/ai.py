# App/backend/schemas/ai.py
from pydantic import BaseModel
from typing import List


class AskAIRequest(BaseModel):
    user_id: int
    question: str
    detailed: bool = False


class AskAIResponse(BaseModel):
    success: bool
    short_answer: str = ""
    detailed_answer: str = ""
    tips: List[str] = []


class GenerateSuggestionsRequest(BaseModel):
    user_id: int


class SuggestionsResponse(BaseModel):
    success: bool
    suggestions: List[dict] = []
