"""
OMS — Database Session Setup
==============================
SQLAlchemy async session factory backed by PostgreSQL.
"""

import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://blauplug:StrongPassword123!@postgres:5432/blauplug_trading",
)

engine = create_engine(DATABASE_URL, pool_pre_ping=True, pool_size=10, max_overflow=20)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

from models import Base  # noqa: E402


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
