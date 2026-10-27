from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from app.deps import Db, CurrentUser
from app.services.rag_service import answer

router = APIRouter(prefix="/chat", tags=["RAG Chat"])

class ChatInput(BaseModel):
    message: str = Field(min_length=2, max_length=2000)

class ChatOutput(BaseModel):
    reply: str
    sources: list[str]

@router.post("", response_model=ChatOutput)
def ask_foodwise(payload: ChatInput, db: Db, user: CurrentUser):
    try:
        return answer(payload.message, db)
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Ollama or recipe search unavailable. Check server and seed data.") from exc
