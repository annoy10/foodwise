from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import Base, engine
from sqlalchemy import text
import app.models  # imports/registers SQLAlchemy tables
from app.routers import auth, foods, meals, extended, chatbot

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Beginner-friendly initial table creation. For schema CHANGES, use Alembic.
    with engine.begin() as connection:
        connection.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))
    Base.metadata.create_all(bind=engine)
    yield

app = FastAPI(title="FoodWise PostgreSQL RAG API", version="1.0.0", lifespan=lifespan)
# Allow Flutter Web on fixed local development port only.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:55000",
        "http://127.0.0.1:55000",
    ],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(foods.router)
app.include_router(meals.router)
app.include_router(extended.router)
app.include_router(chatbot.router)

@app.get("/health")
def health():
    return {"status": "ok", "database": "postgresql"}
