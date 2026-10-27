from datetime import date, datetime, timezone
from decimal import Decimal
from sqlalchemy import Date, DateTime, ForeignKey, Numeric, String, UniqueConstraint, CheckConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    meal_logs: Mapped[list["MealLog"]] = relationship(back_populates="user", cascade="all, delete-orphan")

class Food(Base):
    __tablename__ = "foods"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(150), index=True)
    calories: Mapped[Decimal] = mapped_column(Numeric(9, 2))
    protein: Mapped[Decimal] = mapped_column(Numeric(9, 2))
    carbs: Mapped[Decimal] = mapped_column(Numeric(9, 2))
    fat: Mapped[Decimal] = mapped_column(Numeric(9, 2))
    __table_args__ = (CheckConstraint("calories >= 0 AND protein >= 0 AND carbs >= 0 AND fat >= 0", name="food_nutrients_positive"),)

class MealLog(Base):
    __tablename__ = "meal_logs"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    food_id: Mapped[int] = mapped_column(ForeignKey("foods.id", ondelete="RESTRICT"))
    meal_type: Mapped[str] = mapped_column(String(20))
    quantity_grams: Mapped[Decimal] = mapped_column(Numeric(9, 2))
    eaten_on: Mapped[date] = mapped_column(Date, index=True)
    user: Mapped[User] = relationship(back_populates="meal_logs")
    food: Mapped[Food] = relationship()
    __table_args__ = (CheckConstraint("quantity_grams > 0", name="meal_quantity_positive"),)


class NutritionGoal(Base):
    __tablename__ = "nutrition_goals"
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    calories: Mapped[int] = mapped_column(default=2000)
    protein: Mapped[int] = mapped_column(default=75)
    carbs: Mapped[int] = mapped_column(default=250)
    fat: Mapped[int] = mapped_column(default=65)
    water_ml: Mapped[int] = mapped_column(default=2000)

class UserProfile(Base):
    __tablename__ = "user_profiles"
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    age: Mapped[int | None] = mapped_column(nullable=True)
    height_cm: Mapped[float | None] = mapped_column(nullable=True)
    weight_kg: Mapped[float | None] = mapped_column(nullable=True)

class WaterLog(Base):
    __tablename__ = "water_logs"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    consumed_on: Mapped[date] = mapped_column(Date, index=True)
    amount_ml: Mapped[int] = mapped_column()

class FavoriteFood(Base):
    __tablename__ = "favorite_foods"
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    food_id: Mapped[int] = mapped_column(ForeignKey("foods.id", ondelete="CASCADE"), primary_key=True)
