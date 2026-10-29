
import json
import re

from sqlalchemy import select
from sqlalchemy.orm import Session

from langchain_groq import ChatGroq
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser

from app.models.recipe import RecipeKnowledge
from app.core.config import settings


# ==========================================
# GROQ CLOUD LLM
# ==========================================

llm = ChatGroq(
    model=settings.groq_model,
    api_key=settings.groq_api_key,
    temperature=0.1,
    max_tokens=1800,
)


# ==========================================
# STEP 1: SELECT MATCHING RECIPES
# ==========================================

selection_prompt = ChatPromptTemplate.from_messages([
    (
        "system",
        """
You are FoodWise's recipe search assistant.

Choose up to 5 suitable recipes from the catalog.

RULES:
1. Understand Bengali, English and Banglish.
2. Understand ingredient names in both Bangla and English.
3. Prefer recipes that match ingredients the user has.
4. Never invent recipe IDs.
5. Return ONLY a valid JSON array of integer IDs.
6. Return IDs ordered by relevance.
7. If nothing is relevant, return [].

Example:
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


# ==========================================
# STEP 2: GENERATE BENGALI RECIPE ANSWER
# ==========================================

answer_prompt = ChatPromptTemplate.from_messages([
    (
        "system",
        """
You are FoodWise, a friendly Bengali cooking assistant.

Use only recipes supplied in the retrieved context.

LANGUAGE RULES:
1. Always answer in simple, natural Bengali.
2. Understand Bengali, English and Banglish.
3. Translate recipe names and ingredients into Bengali.
4. Explain cooking methods for beginners.

RECIPE RULES:
1. Recommend at most 2 recipes.
2. If the user asks for one recipe, show only one.
3. Prefer recipes matching available ingredients.
4. Follow the database cooking instructions.
5. Expand cooking instructions into 5 to 7 clear steps.
6. You may explain ordinary preparation steps.
7. Do not invent major ingredients.
8. Do not invent exact cooking times or nutrition values.
9. Ensure meat, fish, seafood and eggs are cooked safely.
10. Avoid repeating the same information.

INGREDIENT RULES:
1. Show all required ingredients in Bengali.
2. Check whether the user explicitly lists ingredients
   that they currently have.
3. ONLY when the user lists available ingredients,
   compare them with the recipe ingredients.
4. Show required ingredients not mentioned by the user
   under the heading "🛒 অনুপস্থিত উপকরণ".
5. If the user listed all required ingredients, write:
   "🛒 অনুপস্থিত উপকরণ: নেই"
6. If the user only asks for a recipe or cooking method,
   OMIT the missing ingredients section completely.
7. Never write "অনুপস্থিত উপকরণ: জানা নেই".
8. Do not assume unmentioned ingredients are available.
9. Treat unmentioned ingredients as not confirmed,
   not as proof that the user does not own them.

FORMATTING RULES:
1. Output plain text only.
2. Never use Markdown formatting characters such as
   **, *, ##, ###, or backticks.
3. Never show "Retrieved recipes", "Context",
   "Database", "Sources", or recipe IDs.
4. Keep each cooking step on a separate line.
5. Use Bengali digits in numbered steps.
6. Never include unrelated recipes.
7. Do not add the missing ingredients heading when
   the user has not listed available ingredients.

RESPONSE FORMAT:

🍲 রেসিপির নাম: [বাংলা রেসিপির নাম]

🥗 প্রয়োজনীয় উপকরণ: [সব উপকরণ বাংলায়]

[Only if the user listed available ingredients:
🛒 অনুপস্থিত উপকরণ: [অনুল্লিখিত প্রয়োজনীয় উপকরণ
অথবা নেই]]

👨‍🍳 রান্নার পদ্ধতি:
১. [প্রথম ধাপ]
২. [দ্বিতীয় ধাপ]
৩. [তৃতীয় ধাপ]
৪. [চতুর্থ ধাপ]
৫. [পঞ্চম ধাপ]
৬. [প্রয়োজনে ষষ্ঠ ধাপ]
৭. [প্রয়োজনে সপ্তম ধাপ]

💚 স্বাস্থ্য পরামর্শ: [সংক্ষিপ্ত পরামর্শ]

For multiple recipes, repeat the same structure.
"""
    ),
    (
        "human",
        "RETRIEVED RECIPES:\n{context}\n\n"
        "USER QUESTION:\n{question}\n\n"
        "AVAILABLE INGREDIENTS PROVIDED: {has_ingredients}"
    )
])

rag_chain = (
    answer_prompt
    | llm
    | StrOutputParser()
)


# ==========================================
# STEP 3: DETECT AVAILABLE INGREDIENTS
# ==========================================

def user_listed_ingredients(question: str) -> bool:
    """
    Determine whether the user explicitly says
    which ingredients they currently have.
    """

    question = question.lower().strip()

    patterns = [
        r"আমার কাছে",
        r"আমার ঘরে",
        r"আমার বাসায়",
        r"আমার বাসায়",
        r"আমার আছে",
        r"আমার কাছে আছে",
        r"বাসায় আছে",
        r"বাসায় আছে",
        r"ঘরে আছে",
        r"\bi have\b",
        r"\bi've got\b",
        r"\bi got\b",
        r"\bavailable ingredients\b",
        r"\bingredients i have\b",
        r"\bamar kache\b",
        r"\bamar kase\b",
        r"\bamar ache\b",
    ]

    return any(
        re.search(pattern, question)
        for pattern in patterns
    )


# ==========================================
# STEP 4: CLEAN RESPONSE
# ==========================================

def clean_response(
    text: str,
    has_ingredients: bool = False
) -> str:

    text = str(text or "").strip()

    # Remove code fences.
    text = re.sub(r"```[^\n]*", "", text)

    # Remove Markdown headings.
    text = re.sub(
        r"(?m)^\s{0,3}#{1,6}\s*",
        "",
        text
    )

    # Remove Markdown emphasis.
    text = text.replace("**", "")
    text = text.replace("__", "")
    text = text.replace("`", "")

    # Remove single Markdown star markers.
    text = text.replace("*", "")

    # Remove technical lines.
    text = re.sub(
        r"(?im)^[^\S\n]*(retrieved recipes|sources|"
        r"recipe context|database context)\s*:.*$",
        "",
        text
    )

    # Remove "missing ingredients" heading if
    # the user did not list available ingredients.
    if not has_ingredients:
        text = re.sub(
            r"(?im)^[^\S\n]*🛒\s*অনুপস্থিত\s+উপকরণ\s*:.*(?:\n|$)",
            "",
            text
        )

        text = re.sub(
            r"(?im)^[^\S\n]*অনুপস্থিত\s+উপকরণ\s*:.*(?:\n|$)",
            "",
            text
        )

    # Never show "জানা নেই" as missing ingredients.
    text = re.sub(
        r"(?im)^[^\S\n]*🛒?\s*অনুপস্থিত\s+উপকরণ\s*:"
        r"\s*জানা নেই\s*(?:\n|$)",
        "",
        text
    )

    # Remove excessive blank lines.
    text = re.sub(r"\n{3,}", "\n\n", text)

    return text.strip()


# ==========================================
# STEP 5: MAIN RAG FUNCTION
# ==========================================

def answer(question: str, db: Session):

    question = (question or "").strip()

    if not question:
        return {
            "reply": (
                "আপনার কাছে কী কী উপকরণ আছে "
                "অথবা কী রান্না করতে চান, লিখুন।"
            ),
            "sources": []
        }

    # Detect ingredient availability list.
    has_ingredients = user_listed_ingredients(question)

    # Read recipe catalog from Supabase.
    recipes = db.scalars(
        select(RecipeKnowledge)
        .order_by(RecipeKnowledge.title)
        .limit(200)
    ).all()

    if not recipes:
        return {
            "reply": (
                "দুঃখিত, বর্তমানে কোনো রেসিপি "
                "পাওয়া যাচ্ছে না।"
            ),
            "sources": []
        }

    # Create temporary recipe IDs.
    recipe_map = {
        index: recipe
        for index, recipe in enumerate(recipes, start=1)
    }

    # Create recipe catalog.
    catalog = "\n".join(
        (
            f"{index}. {recipe.title} | "
            f"Ingredients: {recipe.ingredients}"
        )
        for index, recipe in recipe_map.items()
    )

    # Select matching recipes with Groq.
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
                "অন্য উপকরণ দিয়ে চেষ্টা করুন।"
            ),
            "sources": []
        }

    # Build context from real database recipes.
    context = "\n\n".join(
        (
            f"Recipe: {recipe.title}\n"
            f"Ingredients: {recipe.ingredients}\n"
            f"Cooking Instructions: {recipe.instructions}"
        )
        for recipe in selected_recipes
    )

    # Generate detailed Bengali response.
    response = rag_chain.invoke({
        "context": context,
        "question": question,
        "has_ingredients": (
            "YES - show missing ingredients"
            if has_ingredients
            else "NO - omit missing ingredients section"
        ),
    })

    # Clean text for older Flutter APK.
    response = clean_response(
        response,
        has_ingredients=has_ingredients
    )

    # Keep existing frontend API format.
    return {
        "reply": response,
        "sources": [
            recipe.title
            for recipe in selected_recipes
        ],
    }
