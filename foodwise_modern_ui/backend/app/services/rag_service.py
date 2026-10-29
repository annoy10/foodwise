
import json

from sqlalchemy import select
from sqlalchemy.orm import Session

from langchain_groq import ChatGroq
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser

from app.models.recipe import RecipeKnowledge
from app.core.config import settings


# Groq Cloud LLM
llm = ChatGroq(
    model=settings.groq_model,
    api_key=settings.groq_api_key,
    temperature=0.1,
    max_tokens=800,
)


# Step 1: Recipe selection prompt
selection_prompt = ChatPromptTemplate.from_messages([
    (
        "system",
        """
You are a recipe search assistant.

Select up to 5 recipes that best match the user's question.

The question can be in Bengali or English.
Understand Bengali ingredient names and their English equivalents.

Only select recipe IDs from the supplied catalog.
Never invent IDs.

Return ONLY a valid JSON array of integer IDs.
Example: [2, 4, 1]
If nothing is relevant, return [].
"""
    ),
    (
        "human",
        "RECIPE CATALOG:\n{catalog}\n\n"
        "USER QUESTION:\n{question}"
    )
])

selection_chain = (
    selection_prompt
    | llm
    | StrOutputParser()
)


# Step 2: Final answer prompt
answer_prompt = ChatPromptTemplate.from_messages([
    (
        "system",
        """
You are FoodWise, a helpful Bengali recipe assistant.

Rules:
1. Answer in clear Bengali when the user writes Bengali.
2. Use ONLY the retrieved recipe context.
3. Recommend at most 2 suitable recipes.
4. Prefer recipes matching available ingredients.
5. Mention missing ingredients clearly.
6. Follow cooking instructions from the database.
7. Do not invent ingredients or nutrition values.
8. Avoid repeating sentences.
9. Never recommend spoiled or unsafe food.

Answer format:

🍲 রেসিপির নাম:
🥗 প্রয়োজনীয় উপকরণ:
🛒 অনুপস্থিত উপকরণ:
👩‍🍳 রান্নার পদ্ধতি:
💚 স্বাস্থ্যকর টিপস:
"""
    ),
    (
        "human",
        "RETRIEVED RECIPES:\n{context}\n\n"
        "USER QUESTION:\n{question}"
    )
])

rag_chain = (
    answer_prompt
    | llm
    | StrOutputParser()
)


def answer(question: str, db: Session):

    # Read recipe catalog from Supabase PostgreSQL
    recipes = db.scalars(
        select(RecipeKnowledge)
        .order_by(RecipeKnowledge.title)
        .limit(200)
    ).all()

    if not recipes:
        return {
            "reply": (
                "Recipe knowledge base খালি। "
                "প্রথমে recipe data যোগ করতে হবে।"
            ),
            "sources": []
        }

    # Create short catalog with temporary numeric IDs
    recipe_map = {
        index: recipe
        for index, recipe in enumerate(recipes, start=1)
    }

    catalog = "\n".join(
        f"{index}. {recipe.title} | "
        f"Ingredients: {recipe.ingredients}"
        for index, recipe in recipe_map.items()
    )

    # Groq selects relevant recipe IDs
    selection_text = selection_chain.invoke({
        "catalog": catalog,
        "question": question,
    })

    try:
        start = selection_text.index("[")
        end = selection_text.index("]", start) + 1

        selected_ids = json.loads(
            selection_text[start:end]
        )
    except (ValueError, json.JSONDecodeError):
        selected_ids = []

    if not isinstance(selected_ids, list):
        selected_ids = []

    # Only use recipes that really exist
    selected_recipes = []
    seen = set()

    for recipe_id in selected_ids:
        if type(recipe_id) is not int:
            continue

        if recipe_id in recipe_map and recipe_id not in seen:
            selected_recipes.append(recipe_map[recipe_id])
            seen.add(recipe_id)

        if len(selected_recipes) >= 5:
            break

    if not selected_recipes:
        return {
            "reply": (
                "দুঃখিত, আপনার উপকরণের সঙ্গে "
                "মিল আছে এমন রেসিপি পাওয়া যায়নি।"
            ),
            "sources": []
        }

    # Build context using actual database recipes
    context = "\n\n".join(
        (
            f"Recipe: {recipe.title}\n"
            f"Ingredients: {recipe.ingredients}\n"
            f"Cooking Instructions: {recipe.instructions}"
        )
        for recipe in selected_recipes
    )

    # Generate Bengali answer from retrieved recipes
    response = rag_chain.invoke({
        "context": context,
        "question": question,
    })

    return {
        "reply": response,
        "sources": [
            recipe.title
            for recipe in selected_recipes
        ],
    }
