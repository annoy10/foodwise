import json
from pathlib import Path
from sqlalchemy import text, select
from langchain_ollama import OllamaEmbeddings
from app.core.config import settings
from app.database import Base, SessionLocal, engine
from app.models.recipe import RecipeKnowledge
import app.models

def main():
    with engine.begin() as c:
        c.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))
    Base.metadata.create_all(bind=engine)
    entries = json.loads((Path(__file__).resolve().parent.parent / "data" / "recipes.json").read_text(encoding="utf-8"))
    embeddings = OllamaEmbeddings(model=settings.ollama_embed_model, base_url=settings.ollama_base_url)
    with SessionLocal() as db:
        for r in entries:
            if db.scalar(select(RecipeKnowledge).where(RecipeKnowledge.title == r["title"])):
                continue
            content = f'{r["title"]}: ingredients: {", ".join(r["ingredients"])}. Steps: {r["instructions"]}'
            db.add(RecipeKnowledge(title=r['title'], ingredients=', '.join(r['ingredients']), instructions=r['instructions'], embedding=embeddings.embed_query(content)))
        db.commit()
    print(f"Seed complete: {len(entries)} recipes available in source")

if __name__ == "__main__":
    main()
