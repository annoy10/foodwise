
from sqlalchemy import select
from sqlalchemy.orm import Session
from langchain_ollama import ChatOllama, OllamaEmbeddings
from langchain_core.messages import SystemMessage, HumanMessage

from app.models.recipe import RecipeKnowledge
from app.core.config import settings


_embeddings = OllamaEmbeddings(
    model=settings.ollama_embed_model,
    base_url=settings.ollama_base_url
)

_llm = ChatOllama(
    model=settings.ollama_chat_model,
    base_url=settings.ollama_base_url,
    temperature=0.1,
    num_predict=550,
    repeat_penalty=1.15
)


SYSTEM_PROMPT = """
You are FoodWise, a helpful Bengali recipe assistant.

Your job is to recommend practical recipes based on the user's
available ingredients, using the retrieved recipe database.

STRICT RULES:

1. Answer in natural, clear Bengali if the user writes in Bengali.
2. Use ONLY the recipes provided in the retrieved context.
3. Recommend a maximum of TWO recipes.
4. Prioritize recipes that use the user's available ingredients.
5. Never falsely claim that the user has an ingredient.
6. Clearly identify any missing ingredients.
7. Do not invent cooking steps, quantities, or nutrition values.
8. Do not repeat sentences or recommendations.
9. Do not include unrelated recipes.
10. If no suitable recipe is found, explain this politely.
11. Do not recommend spoiled or unsafe food.

ANSWER FORMAT:

🍲 রেসিপির নাম: [Recipe name]

🥗 প্রয়োজনীয় উপকরণ:
- List the ingredients from the retrieved recipe.
- Mention which ingredients the user is missing.

👩‍🍳 রান্নার পদ্ধতি:
1. Write the first cooking step.
2. Write the next steps in order.
3. Include all relevant steps from the recipe context.

💚 স্বাস্থ্যকর টিপস:
Give one short practical tip without inventing nutrition facts.

IMPORTANT:
Write one complete useful answer.
Avoid repeating the same idea.
Prefer accurate instructions over unnecessary explanations.
"""


def answer(question: str, db: Session):

    # 1. Convert the user's question into an embedding
    vector = _embeddings.embed_query(question)

    # 2. Find the 5 most semantically similar recipes
    hits = db.scalars(
        select(RecipeKnowledge)
        .order_by(
            RecipeKnowledge.embedding.cosine_distance(vector)
        )
        .limit(5)
    ).all()

    # 3. Handle an empty recipe knowledge base
    if not hits:
        return {
            "reply": (
                "Recipe knowledge base খালি। "
                "প্রথমে python -m app.seed_recipes চালাও।"
            ),
            "sources": []
        }

    # 4. Build context from retrieved recipes
    context = "\n\n".join(
        (
            f"Recipe {i}: {r.title}\n"
            f"Ingredients: {r.ingredients}\n"
            f"Cooking instructions: {r.instructions}"
        )
        for i, r in enumerate(hits, 1)
    )

    # 5. Prepare the messages for Ollama
    msgs = [
        SystemMessage(content=SYSTEM_PROMPT),
        HumanMessage(
            content=(
                f"RETRIEVED RECIPE CONTEXT:\n{context}\n\n"
                f"USER QUESTION:\n{question}\n\n"
                "Follow the requested answer format. "
                "Recommend only suitable recipes from the context."
            )
        )
    ]

    # 6. Generate the AI response
    response = _llm.invoke(msgs)

    # 7. Return the response and retrieved sources
    return {
        "reply": str(response.content),
        "sources": [r.title for r in hits]
    }
