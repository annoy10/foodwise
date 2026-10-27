from datetime import date
from decimal import Decimal
from fastapi import APIRouter, HTTPException
from sqlalchemy import select
from app.deps import Db, CurrentUser
from app.models import Food, MealLog
from app.schemas import MealCreate, MealOut, DailySummary

router = APIRouter(prefix="/meals", tags=["meals"])

@router.post("", response_model=MealOut, status_code=201)
def add_meal(data: MealCreate, db: Db, user: CurrentUser):
    if not db.get(Food, data.food_id):
        raise HTTPException(404, "Food not found")
    meal = MealLog(**data.model_dump(), user_id=user.id)
    db.add(meal)
    db.commit()
    db.refresh(meal)
    return meal

@router.get("", response_model=list[MealOut])
def list_meals(db: Db, user: CurrentUser, on: date | None = None):
    stmt = select(MealLog).where(MealLog.user_id == user.id)
    if on is not None:
        stmt = stmt.where(MealLog.eaten_on == on)
    return db.scalars(stmt.order_by(MealLog.id.desc()).limit(200)).all()

@router.put("/{meal_id}", response_model=MealOut)
def edit_meal(meal_id: int, data: MealCreate, db: Db, user: CurrentUser):
    meal = db.scalar(select(MealLog).where(MealLog.id == meal_id, MealLog.user_id == user.id))
    if not meal: raise HTTPException(404, "Meal not found")
    if not db.get(Food, data.food_id): raise HTTPException(404, "Food not found")
    for key, value in data.model_dump().items(): setattr(meal, key, value)
    db.commit(); db.refresh(meal)
    return meal

@router.delete("/{meal_id}", status_code=204)
def delete_meal(meal_id: int, db: Db, user: CurrentUser):
    meal = db.scalar(select(MealLog).where(MealLog.id == meal_id, MealLog.user_id == user.id))
    if not meal:
        raise HTTPException(404, "Meal not found")
    db.delete(meal)
    db.commit()

@router.get("/summary", response_model=DailySummary)
def summary(on: date, db: Db, user: CurrentUser):
    meals = db.scalars(select(MealLog).where(MealLog.user_id == user.id, MealLog.eaten_on == on)).all()
    totals = {key: Decimal("0") for key in ("calories", "protein", "carbs", "fat")}
    for meal in meals:
        food = db.get(Food, meal.food_id)
        multiplier = Decimal(str(meal.quantity_grams)) / Decimal("100")
        for key in totals:
            totals[key] += Decimal(str(getattr(food, key))) * multiplier
    return DailySummary(date=on, **{k: v.quantize(Decimal("0.01")) for k, v in totals.items()})
