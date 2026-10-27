from sqlalchemy import select
from sqlalchemy.orm import Session
from langchain_ollama import ChatOllama, OllamaEmbeddings
from langchain_core.messages import SystemMessage, HumanMessage
from app.models.recipe import RecipeKnowledge
from app.core.config import settings

_embeddings = OllamaEmbeddings(model=settings.ollama_embed_model, base_url=settings.ollama_base_url)
_llm = ChatOllama(model=settings.ollama_chat_model, base_url=settings.ollama_base_url, temperature=0.2)

def answer(question: str, db: Session):
    vector = _embeddings.embed_query(question)
    hits = db.scalars(select(RecipeKnowledge).order_by(RecipeKnowledge.embedding.cosine_distance(vector)).limit(5)).all()
    if not hits:
        return {"reply": "Recipe knowledge base খালি। প্রথমে python -m app.seed_recipes চালাও।", "sources": []}
    context = "\n\n".join(
        f"Recipe {i}: {r.title}\nIngredients: {r.ingredients}\nMethod: {r.instructions}"
        for i, r in enumerate(hits, 1)
    )
    msgs = [
        SystemMessage(content=(
            "You are FoodWise, a Bengali-friendly ingredient-based recipe assistant. "
            "Use ONLY the recipes in CONTEXT. Suggest recipes using user's available ingredients, "
            "clearly list missing ingredients. Do not claim an exact match unless all needed ingredients "
            "are available. Do not invent ingredient quantities. Respond in the language of the user. "
            "If sources do not fit, say no suitable recipe found. Never advise eating spoiled food."
        )),
        HumanMessage(content=f"CONTEXT:\n{context}\n\nUSER QUESTION:\n{question}"),
    ]
    response = _llm.invoke(msgs)
    return {"reply": str(response.content), "sources": [r.title for r in hits]}
