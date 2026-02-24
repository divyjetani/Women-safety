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
