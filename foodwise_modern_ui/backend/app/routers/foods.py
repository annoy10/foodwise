from fastapi import APIRouter
from sqlalchemy import select
from app.deps import Db, CurrentUser
from app.models import Food
from app.schemas import FoodCreate, FoodOut

router = APIRouter(prefix="/foods", tags=["foods"])

@router.get("", response_model=list[FoodOut])
def list_foods(db: Db, user: CurrentUser, q: str = ""):
    stmt = select(Food).where(Food.name.ilike(f"%{q}%")).order_by(Food.name).limit(100)
    return db.scalars(stmt).all()

@router.post("", response_model=FoodOut, status_code=201)
def create_food(data: FoodCreate, db: Db, user: CurrentUser):
    food = Food(**data.model_dump())
    db.add(food)
    db.commit()
    db.refresh(food)
    return food
