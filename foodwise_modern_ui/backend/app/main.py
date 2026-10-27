
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.database import Base, engine
import app.models  # Register SQLAlchemy models
from app.routers import auth, foods, meals, extended, chatbot


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Ensure pgvector extension exists
    with engine.begin() as connection:
        connection.execute(
            text("CREATE EXTENSION IF NOT EXISTS vector")
        )

    # Create tables that do not already exist
    Base.metadata.create_all(bind=engine)

    yield


app = FastAPI(
    title="FoodWise PostgreSQL RAG API",
    version="1.0.0",
    lifespan=lifespan,
)

# Allow Flutter Web frontend to access the backend

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://nimble-rolypoly-7d5bc6.netlify.app",
        "https://helpful-vacherin-840342.netlify.app",
        "https://foodwise-app.pages.dev",
    ],
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1):\d+",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API routers
app.include_router(auth.router)
app.include_router(foods.router)
app.include_router(meals.router)
app.include_router(extended.router)
app.include_router(chatbot.router)


@app.get("/health")
def health():
    return {
        "status": "ok",
        "database": "postgresql",
    }
