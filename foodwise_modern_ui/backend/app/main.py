
from contextlib import asynccontextmanager
import logging
import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.database import Base, engine
import app.models

from app.routers import (
    auth,
    foods,
    meals,
    extended,
    chatbot,
)


logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):

    # Local testing:
    # SKIP_DB_STARTUP=true skips database initialization.
    skip_db = os.getenv(
        "SKIP_DB_STARTUP", "false"
    ).lower() == "true"

    if skip_db:
        logger.warning(
            "Skipping database initialization "
            "(SKIP_DB_STARTUP=true)"
        )
    else:
        # Database initialization for normal deployment
        with engine.begin() as connection:
            connection.execute(
                text(
                    "CREATE EXTENSION IF NOT EXISTS vector"
                )
            )

        Base.metadata.create_all(bind=engine)

    yield


app = FastAPI(
    title="FoodWise PostgreSQL RAG API",
    version="1.0.0",
    lifespan=lifespan,
)


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
