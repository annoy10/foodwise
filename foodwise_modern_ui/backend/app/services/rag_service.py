
import json
import re

from sqlalchemy import select
from sqlalchemy.orm import Session

from langchain_groq import ChatGroq
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser

from app.models.recipe import RecipeKnowledge
from app.core.config import settings


# --------------------------------------------------
# Groq Cloud LLM
# --------------------------------------------------

llm = ChatGroq(
    model=settings.groq_model,
    api_key=settings.groq_api_key,
    temperature=0.1,
    max_tokens=1800,
)


# --------------------------------------------------
# STEP 1: Select matching recipes
# --------------------------------------------------

selection_prompt = ChatPromptTemplate.from_messages([
    (
        "system",
        """
You are FoodWise's recipe search assistant.

Select up to 5 relevant recipes from the supplied catalog.

Rules:
1. Understand Bengali, English and Banglish questions.
2. Understand Bengali ingredient names and their English equivalents.
3. Prefer recipes matching ingredients the user actually has.
4. Do not assume the user has ingredients they did not mention.
5. Only select numeric IDs from the supplied catalog.
6. Never invent recipe IDs.
7. Return ONLY a JSON array of integer IDs.
8. Order IDs from most relevant to least relevant.
9. If no relevant recipe exists, return [].

Example output:
[2, 4, 1]
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


# --------------------------------------------------
# STEP 2: Generate detailed Bangla recipe answers
# --------------------------------------------------

answer_prompt = ChatPromptTemplate.from_messages([
    (
        "system",
        """
You are FoodWise, a friendly Bengali cooking assistant.

Your task is to explain real recipes retrieved from the
FoodWise recipe database.

LANGUAGE RULES:
1. Always answer in natural, simple Bangla.
2. Understand Bengali, English and Banglish questions.
3. Translate English recipe names into Bangla.
4. Translate ingredient names into Bangla.
5. Use friendly and easy cooking instructions.

RECIPE RULES:
1. Use only recipes supplied in the retrieved context.
2. Recommend a maximum of 2 recipes.
3. If the user requests one recipe, explain only one.
4. Prefer recipes matching the user's ingredients.
5. Use the database instructions as the factual basis.
6. Expand short instructions into 5 to 7 practical steps.
7. You may explain ordinary preparation and cooking techniques.
8. Do not invent major ingredients or unsupported claims.
9. Do not invent specific cooking times or nutrition values.
10. Never suggest unsafe or spoiled food.
11. Make sure meat, fish, eggs and seafood are cooked safely.
12. Avoid repeating sentences or unnecessary explanations.

INGREDIENT RULES:
1. Show the complete ingredient list for the selected recipe.
2. If the user lists available ingredients, compare them
   with the recipe ingredients.
3. Clearly identify missing ingredients.
4. Never assume unmentioned ingredients are available.
5. If the user did not list available ingredients, write
   "জানা নেই" in the missing ingredients section.

FORMATTING RULES:
1. Output ONLY plain text.
2. Never use Markdown characters such as **, *, #, or backticks.
3. Never show technical headings such as:
   "Retrieved recipes", "Context", "Database", "Sources".
4. Do not mention recipe IDs, model names or database queries.
5. Keep each cooking step on its own line.
6. Use Bengali digits for numbered cooking steps.
7. Do not add extra unrelated recipes.

For EACH recommended recipe, follow this format:

🍲 রেসিপির নাম: [রেসিপির বাংলা নাম]

🥗 প্রয়োজনীয় উপকরণ: [সব উপকরণ বাংলায়]

🛒 অনুপস্থিত উপকরণ: [অনুপস্থিত উপকরণ;
যদি কিছু অনুপস্থিত না থাকে লিখবে "নেই";
উপলব্ধ উপকরণ না জানলে লিখবে "জানা নেই"]

👨‍🍳 রান্নার পদ্ধতি:
১. [প্রথম ধাপ]
২. [দ্বিতীয় ধাপ]
৩. [তৃতীয় ধাপ]
৪. [চতুর্থ ধাপ]
৫. [পঞ্চম ধাপ]
৬. [প্রয়োজনে ষষ্ঠ ধাপ]
৭. [প্রয়োজনে সপ্তম ধাপ]

💚 স্বাস্থ্য পরামর্শ: [একটি সংক্ষিপ্ত, প্রাসঙ্গিক পরামর্শ]

Remember: Detailed, beginner-friendly Bengali instructions.
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


# --------------------------------------------------
# STEP 3: Clean unwanted Markdown characters
# --------------------------------------------------

def clean_response(text: str) -> str:
    """
    Remove Markdown formatting for older Flutter APKs
    that display Markdown as raw text.
    """

    text = str(text or "").strip()

    # Remove fenced code markers, if any.
    text = re.sub(r"```[^\n]*", "", text)

    # Remove Markdown heading markers.
    text = re.sub(r"(?m)^\s{0,3}#{1,6}\s*", "", text)

    # Remove Markdown bold / italic markers.
    text = text.replace("**", "")
    text = text.replace("__", "")

    # Remove single Markdown emphasis markers.
    text = text.replace("*", "")
    text = text.replace("`", "")

    # Remove accidental technical headings.
    text = re.sub(
        r"(?im)^\s*(retrieved recipes|sources|"
        r"recipe context|database context)\s*:.*$",
        "",
        text,
    )

    # Avoid excessive blank lines.
    text = re.sub(r"\n{3,}", "\n\n", text)

    return text.strip()


# --------------------------------------------------
# STEP 4: Main RAG Answer Function
# --------------------------------------------------

def answer(question: str, db: Session):

    question = (question or "").strip()

    if not question:
        return {
            "reply": "আপনি কী রান্না করতে চান বা কী কী উপকরণ আছে লিখুন।",
            "sources": []
        }

    # Read recipes from Supabase PostgreSQL.
    recipes = db.scalars(
        select(RecipeKnowledge)
        .order_by(RecipeKnowledge.title)
        .limit(200)
    ).all()

    if not recipes:
        return {
            "reply": (
                "দুঃখিত, বর্তমানে কোনো রেসিপি পাওয়া যাচ্ছে না।"
            ),
            "sources": []
        }

    # Temporary IDs for recipe selection.
    recipe_map = {
        index: recipe
        for index, recipe in enumerate(recipes, start=1)
    }

    # Build compact recipe catalog.
    catalog = "\n".join(
        (
            f"{index}. {recipe.title} | "
            f"Ingredients: {recipe.ingredients}"
        )
        for index, recipe in recipe_map.items()
    )

    # Ask Groq to select relevant recipe IDs.
    selection_text = selection_chain.invoke({
        "catalog": catalog,
        "question": question,
    })

    # Parse selected IDs safely.
    try:
        match = re.search(
            r"\[[\s\S]*?\]",
            selection_text
        )

        selected_ids = (
            json.loads(match.group(0))
            if match
            else []
        )

    except (ValueError, TypeError):
        selected_ids = []

    if not isinstance(selected_ids, list):
        selected_ids = []

    selected_recipes = []
    seen = set()

    for recipe_id in selected_ids:

        if type(recipe_id) is not int:
            continue

        if (
            recipe_id in recipe_map
            and recipe_id not in seen
        ):
            selected_recipes.append(
                recipe_map[recipe_id]
            )
            seen.add(recipe_id)

        if len(selected_recipes) >= 5:
            break

    if not selected_recipes:
        return {
            "reply": (
                "দুঃখিত, আপনার প্রশ্নের সঙ্গে মিল আছে "
                "এমন কোনো রেসিপি পাওয়া যায়নি। "
                "অন্য কিছু উপকরণের নাম দিয়ে চেষ্টা করুন।"
            ),
            "sources": []
        }

    # Pass only actual selected database recipes.
    context = "\n\n".join(
        (
            f"Recipe: {recipe.title}\n"
            f"Ingredients: {recipe.ingredients}\n"
            f"Cooking Instructions: {recipe.instructions}"
        )
        for recipe in selected_recipes
    )

    # Generate final detailed Bengali answer.
    response = rag_chain.invoke({
        "context": context,
        "question": question,
    })

    # Remove raw Markdown formatting.
    response = clean_response(response)

    # Preserve existing API response format.
    return {
        "reply": response,
        "sources": [
            recipe.title
            for recipe in selected_recipes
        ],
    }
