"""
API Gateway — JWT Authentication & RBAC
==========================================
Manages JWT token creation, validation, and role-based access control.
"""

import os
import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

from jose import jwt, JWTError
from passlib.context import CryptContext
from pydantic import BaseModel, EmailStr, Field, validator
import redis
import psycopg2
from psycopg2.extras import RealDictCursor

logger = logging.getLogger("api-gateway.auth")

SECRET_KEY      = os.getenv("SECRET_KEY", "change-me-to-a-random-64-char-string")
ALGORITHM       = os.getenv("JWT_ALGORITHM", "HS256")
EXPIRE_MINUTES  = int(os.getenv("JWT_EXPIRE_MINUTES", "60"))

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Redis connection for session caching
REDIS_HOST = os.getenv("REDIS_HOST", "redis")
REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))
redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)

# PostgreSQL connection for user persistence
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://blauplug:StrongPassword123!@postgres:5432/blauplug_trading")


def get_db_connection():
    """Create a database connection."""
    return psycopg2.connect(DATABASE_URL)


# ── Hardcoded user store (replace with DB in production) ──────────────────────
# Passwords are bcrypt hashes. Default: admin / Admin@1234
USERS_DB = {
    "admin": {
        "user_id":  "00000000-0000-0000-0000-000000000001",
        "username": "admin",
        "role":     "admin",
        "password_hash": "$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TqzneflfijxivzsGGdnqKDmkBJCa",
    },
}


# ── Pydantic Schemas ──────────────────────────────────────────────────────────

class LoginRequest(BaseModel):
    username: str
    password: str


class RegisterRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=64)
    email: EmailStr
    password: str = Field(..., min_length=8)
    role: str = Field(default="trader")

    @validator('role')
    def validate_role(cls, v):
        if v not in ('admin', 'trader', 'viewer'):
            raise ValueError('role must be admin, trader, or viewer')
        return v

    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('password must be at least 8 characters')
        if not any(c.isupper() for c in v):
            raise ValueError('password must contain at least one uppercase letter')
        if not any(c.islower() for c in v):
            raise ValueError('password must contain at least one lowercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('password must contain at least one digit')
        return v


class UserResponse(BaseModel):
    user_id: str
    username: str
    email: str
    role: str
    created_at: Optional[str] = None


class TokenResponse(BaseModel):
    access_token: str
    token_type:   str = "bearer"
    expires_in:   int
    user_id:      str
    role:         str


# ── User Management Functions ─────────────────────────────────────────────────

def create_user(username: str, email: str, password: str, role: str = "trader") -> Optional[dict]:
    """Create a new user in the database."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Check if username or email already exists
        cursor.execute("SELECT id FROM users WHERE username = %s OR email = %s", (username, email))
        if cursor.fetchone():
            cursor.close()
            conn.close()
            return None  # User already exists
        
        # Hash password and create user
        password_hash = pwd_context.hash(password)
        user_id = str(uuid.uuid4())
        
        cursor.execute("""
            INSERT INTO users (id, username, email, password_hash, role, is_active)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id, username, email, role, created_at
        """, (user_id, username, email, password_hash, role, True))
        
        user = cursor.fetchone()
        
        # Create portfolio for the user
        cursor.execute("""
            INSERT INTO portfolios (user_id, cash_balance)
            VALUES (%s, %s)
        """, (user_id, 100000.00))  # Default ₹1,00,000 starting balance
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return dict(user)
    except Exception as e:
        logger.error(f"Error creating user: {e}")
        return None


def get_user_by_credentials(username: str, password: str) -> Optional[dict]:
    """Authenticate user by username and password."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute("SELECT * FROM users WHERE username = %s AND is_active = %s", (username, True))
        user = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if user and pwd_context.verify(password, user['password_hash']):
            return dict(user)
        return None
    except Exception as e:
        logger.error(f"Error authenticating user: {e}")
        return None


def get_user_by_id(user_id: str) -> Optional[dict]:
    """Get user by ID from database."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute("SELECT id, username, email, role, created_at FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
        cursor.close()
        conn.close()
        
        return dict(user) if user else None
    except Exception as e:
        logger.error(f"Error fetching user: {e}")
        return None


# ── Token Utilities ───────────────────────────────────────────────────────────

def create_token(
    username: str,
    password: Optional[str] = None,
    _refresh: bool = False,
    existing_payload: Optional[dict] = None,
) -> Optional[TokenResponse]:
    """Create a signed JWT token for the given user."""
    # Try database first, fallback to hardcoded USERS_DB
    user = None
    if not _refresh:
        user = get_user_by_credentials(username, password or "")
        if not user:
            user = USERS_DB.get(username)
            if user and not pwd_context.verify(password or "", user["password_hash"]):
                return None
    else:
        # Refresh token - get from existing payload
        user = get_user_by_id(existing_payload.get("user_id")) if existing_payload else None
        if not user:
            user = USERS_DB.get(existing_payload.get("sub")) if existing_payload else None
    
    if not user:
        return None

    expire = datetime.now(tz=timezone.utc) + timedelta(minutes=EXPIRE_MINUTES)
    payload = {
        "sub":     user.get("username", user.get("username")),
        "user_id": str(user.get("user_id", user.get("id"))),
        "role":    user.get("role", "trader"),
        "exp":     expire,
        "iat":     datetime.now(tz=timezone.utc),
        "jti":     str(uuid.uuid4()),
    }
    token = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
    return TokenResponse(
        access_token=token,
        expires_in=EXPIRE_MINUTES * 60,
        user_id=str(user.get("user_id", user.get("id"))),
        role=user.get("role", "trader"),
    )


def verify_token(token: str) -> Optional[dict]:
    """Decode and validate a JWT token. Returns payload dict or None."""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError as exc:
        logger.warning("JWT validation failed: %s", exc)
        return None


# ── RBAC Utility ──────────────────────────────────────────────────────────────

def require_role(*roles: str):
    """Dependency factory for role-based access control."""
    from fastapi import Depends, HTTPException, status
    from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

    _security = HTTPBearer()

    async def _check(credentials: HTTPAuthorizationCredentials = Depends(_security)) -> dict:
        payload = verify_token(credentials.credentials)
        if not payload:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token.")
        if payload.get("role") not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Requires one of roles: {roles}",
            )
        return payload

    return _check
