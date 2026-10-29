
import json
from pathlib import Path

from sqlalchemy import select

from app.database import Base, SessionLocal, engine
from app.models.recipe import RecipeKnowledge
import app.models


def main():
    Base.metadata.create_all(bind=engine)

    file_path = (
        Path(__file__).resolve().parent.parent
        / "data"
        / "recipes.json"
    )

    entries = json.loads(
        file_path.read_text(encoding="utf-8")
    )

    added = 0

    with SessionLocal() as db:
        for r in entries:
            existing = db.scalar(
                select(RecipeKnowledge).where(
                    RecipeKnowledge.title == r["title"]
                )
            )

            if existing:
                continue

            db.add(
                RecipeKnowledge(
                    title=r["title"],
                    ingredients=", ".join(r["ingredients"]),
                    instructions=r["instructions"],
                    embedding=None
                )
            )

            added += 1

        db.commit()

    print(f"Seed complete: {added} new recipes added.")


if __name__ == "__main__":
    main()
