from decimal import Decimal
from pydantic import BaseModel, ConfigDict, Field, field_validator

class FoodCreate(BaseModel):
    name: str = Field(min_length=2, max_length=150)
    calories: Decimal = Field(ge=0, max_digits=9, decimal_places=2)
    protein: Decimal = Field(ge=0, max_digits=9, decimal_places=2)
    carbs: Decimal = Field(ge=0, max_digits=9, decimal_places=2)
    fat: Decimal = Field(ge=0, max_digits=9, decimal_places=2)

    @field_validator("name")
    @classmethod
    def strip_name(cls, value: str) -> str:
        value = value.strip()
        if len(value) < 2:
            raise ValueError("Food name must have at least 2 characters")
        return value

class FoodOut(FoodCreate):
    id: int
    model_config = ConfigDict(from_attributes=True)
