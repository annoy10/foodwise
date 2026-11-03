
import hashlib
import logging
import secrets

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from sqlalchemy import BigInteger, DateTime, String, select
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from app.deps import Db, CurrentUser
from app.models import User
from app.schemas import UserCreate, UserOut, LoginIn
from app.core.security import (
    create_access_token,
    hash_password,
    verify_password,
)


logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/auth",
    tags=["auth"],
)

REFRESH_TOKEN_DAYS = 30


# ==========================================
# DATABASE MODEL
# ==========================================

class RefreshSession(Base):
    __tablename__ = "refresh_sessions"

    id: Mapped[int] = mapped_column(
        BigInteger,
        primary_key=True,
        autoincrement=True,
    )

    user_id: Mapped[int] = mapped_column(
        BigInteger,
        nullable=False,
        index=True,
    )

    token_hash: Mapped[str] = mapped_column(
        String(64),
        unique=True,
        nullable=False,
    )

    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )


# ==========================================
# REQUEST / RESPONSE SCHEMAS
# ==========================================

class LoginTokens(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshInput(BaseModel):
    refresh_token: str


class LogoutOutput(BaseModel):
    message: str


# ==========================================
# TOKEN HELPERS
# ==========================================

def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(
        token.encode("utf-8")
    ).hexdigest()


def generate_refresh_token() -> str:
    return secrets.token_urlsafe(48)


def create_refresh_session(
    user_id: int,
    db: Db,
) -> str:

    token = generate_refresh_token()

    expires_at = (
        datetime.now(timezone.utc)
        + timedelta(days=REFRESH_TOKEN_DAYS)
    )

    session = RefreshSession(
        user_id=user_id,
        token_hash=hash_refresh_token(token),
        expires_at=expires_at,
    )

    try:
        db.add(session)
        db.commit()

    except SQLAlchemyError:
        db.rollback()
        logger.exception(
            "Failed to create refresh session"
        )
        raise HTTPException(
            status_code=500,
            detail="Unable to create login session",
        )

    return token


# ==========================================
# REGISTER
# ==========================================

@router.post(
    "/register",
    response_model=UserOut,
    status_code=201,
)
def register(data: UserCreate, db: Db):

    email = str(data.email).strip().lower()

    existing_user = db.scalar(
        select(User).where(
            User.email == email
        )
    )

    if existing_user:
        raise HTTPException(
            status_code=409,
            detail="Email already registered",
        )

    user = User(
        name=data.name,
        email=email,
        password_hash=hash_password(
            data.password
        ),
    )

    db.add(user)

    try:
        db.commit()

    except IntegrityError:
        db.rollback()

        raise HTTPException(
            status_code=409,
            detail="Email already registered",
        )

    db.refresh(user)

    return user


# ==========================================
# LOGIN
# ==========================================

@router.post(
    "/login",
    response_model=LoginTokens,
)
def login(data: LoginIn, db: Db):

    email = str(data.email).strip().lower()

    user = db.scalar(
        select(User).where(
            User.email == email
        )
    )

    if (
        user is None
        or not verify_password(
            data.password,
            user.password_hash,
        )
    ):
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password",
        )

    refresh_token = create_refresh_session(
        user_id=user.id,
        db=db,
    )

    access_token = create_access_token(
        user.id
    )

    return LoginTokens(
        access_token=access_token,
        refresh_token=refresh_token,
    )


# ==========================================
# REFRESH ACCESS TOKEN
# ==========================================

@router.post(
    "/refresh",
    response_model=LoginTokens,
)
def refresh_token(
    data: RefreshInput,
    db: Db,
):

    token_hash = hash_refresh_token(
        data.refresh_token
    )

    try:
        session = db.scalar(
            select(RefreshSession)
            .where(
                RefreshSession.token_hash
                == token_hash
            )
            .with_for_update()
        )

        if session is None:
            raise HTTPException(
                status_code=401,
                detail="Invalid refresh token",
            )

        now = datetime.now(timezone.utc)

        if session.expires_at <= now:
            db.delete(session)
            db.commit()

            raise HTTPException(
                status_code=401,
                detail="Refresh token expired",
            )

        user = db.scalar(
            select(User).where(
                User.id == session.user_id
            )
        )

        if user is None:
            db.delete(session)
            db.commit()

            raise HTTPException(
                status_code=401,
                detail="User not found",
            )

        new_refresh_token = (
            generate_refresh_token()
        )

        session.token_hash = hash_refresh_token(
            new_refresh_token
        )

        session.expires_at = (
            now + timedelta(
                days=REFRESH_TOKEN_DAYS
            )
        )

        db.commit()

        new_access_token = (
            create_access_token(user.id)
        )

        return LoginTokens(
            access_token=new_access_token,
            refresh_token=new_refresh_token,
        )

    except HTTPException:
        db.rollback()
        raise

    except SQLAlchemyError:
        db.rollback()

        logger.exception(
            "Failed to refresh login session"
        )

        raise HTTPException(
            status_code=500,
            detail="Unable to refresh session",
        )


# ==========================================
# LOGOUT
# ==========================================

@router.post(
    "/logout",
    response_model=LogoutOutput,
)
def logout(
    data: RefreshInput,
    db: Db,
):

    token_hash = hash_refresh_token(
        data.refresh_token
    )

    try:
        session = db.scalar(
            select(RefreshSession).where(
                RefreshSession.token_hash
                == token_hash
            )
        )

        if session is not None:
            db.delete(session)
            db.commit()

    except SQLAlchemyError:
        db.rollback()

        logger.exception(
            "Failed to revoke refresh session"
        )

        raise HTTPException(
            status_code=500,
            detail="Unable to log out",
        )

    return LogoutOutput(
        message="Logged out successfully"
    )


# ==========================================
# CURRENT USER
# ==========================================

@router.get(
    "/me",
    response_model=UserOut,
)
def me(user: CurrentUser):
    return user
