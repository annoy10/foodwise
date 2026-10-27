from datetime import date
from decimal import Decimal
from typing import Literal
from pydantic import BaseModel, ConfigDict, Field

MealType = Literal["breakfast", "lunch", "dinner", "snack"]

class MealCreate(BaseModel):
    food_id: int = Field(gt=0)
    meal_type: MealType
    quantity_grams: Decimal = Field(gt=0, max_digits=9, decimal_places=2)
    eaten_on: date

class MealOut(MealCreate):
    id: int
    user_id: int
    model_config = ConfigDict(from_attributes=True)

class DailySummary(BaseModel):
    date: date
    calories: Decimal
    protein: Decimal
    carbs: Decimal
    fat: Decimal
