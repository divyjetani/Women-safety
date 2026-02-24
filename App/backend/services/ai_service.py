from typing import List
from utils.logger import logger
import warnings
warnings.filterwarnings('ignore', category=FutureWarning)
import google.generativeai as genai
from config.settings import GEMINI_API_KEY

class AIService:
    def __init__(self):
        if not GEMINI_API_KEY:
            logger.warning("⚠️ GEMINI_API_KEY not found in environment variables")
            self.model = None
        else:
            genai.configure(api_key=GEMINI_API_KEY)
            self.model = genai.GenerativeModel("gemini-3-flash-preview")
        
        logger.info("initialized Gemini API")
    
    async def ask_question(
        self,
        user_id: int,
        question: str,
        detailed: bool = False,
    ) -> dict:
        try:
            if not question.strip():
                return {
                    "success": False,
                    "error": "Question cannot be empty"
                }

            if not GEMINI_API_KEY:
                return {
                    "success": False,
                    "error": "GEMINI_API_KEY not configured"
                }

            if detailed:
                prompt = f"""
You are a helpful safety assistant for a women safety app.
Answer the user question in a detailed way with headings + steps.

User Question: {question}

Rules:
- Keep it helpful, safe and clear.
- Use bullet points if needed.
- Give practical steps.
- If user asks anything else except women safety please say, you can't do it, you will only answer for women safety
- do use md file syntax (do not add **bold**  or *italic* syntax). add --- before h3 heading. and also give one h1 (it should be short one line solution), also you can use h2 if needed.
- max 20 Lines
"""
            else:
                prompt = f"""
You are a helpful safety assistant for a women safety app.
Answer the user question in a short response (max 3 lines).
User Question: {question}

Rules:
- Max 3 lines.
- Simple and actionable.
- If user asks anything else except women safety please say, you can't do it, you will only answer for women safety
"""

            # Call Gemini API
            if not self.model:
                return {
                    "success": False,
                    "error": "Gemini API model not initialized"
                }
            
            response = self.model.generate_content(prompt)
            text = response.text if response.text else "Unable to generate response"

            # Generate tips based on question keywords
            tips = self._generate_tips(question)

            if detailed:
                return {
                    "success": True,
                    "short_answer": "",
                    "detailed_answer": text + "\n--- \n> Note: This is an AI generated response, If you are in any emergency then call on police helpline: 112 or women helpline: 181",
                    "tips": tips,
                }

            return {
                "success": True,
                "short_answer": text,
                "detailed_answer": "",
                "tips": tips,
            }

        except Exception as e:
            logger.error(f"AI error: {e}")
            return {
                "success": False,
                "error": str(e),
            }

    @staticmethod
    def _generate_tips(question: str) -> List[str]:
        """Generate safety tips based on question"""
        q_lower = question.lower()
        
        if "sos" in q_lower:
            return ["Use SOS quickly", "Share live location", "Keep emergency contacts updated"]
        elif "night" in q_lower or "safe" in q_lower:
            return ["Stay in well-lit areas", "Avoid shortcuts", "Keep phone charged"]
        else:
            return ["Stay alert", "Share location", "Trust your instincts"]
