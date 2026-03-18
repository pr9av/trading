"""
Blauplug Trading Platform — API Gateway
=========================================
Central entry point for all client-facing traffic.
Handles: JWT authentication, RBAC, rate limiting, request routing,
and WebSocket relay for real-time market data.
"""

import logging
import os
import httpx
import uvicorn

from fastapi import FastAPI, Depends, HTTPException, WebSocket, WebSocketDisconnect, status, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.exceptions import RequestValidationError
from prometheus_fastapi_instrumentator import Instrumentator

from auth import create_token, verify_token, LoginRequest, TokenResponse, RegisterRequest, UserResponse, create_user, get_user_by_id
from exceptions import (
    AppException, ValidationException, AuthenticationException,
    AuthorizationException, ResourceNotFoundException, RateLimitException,
    app_exception_handler, validation_exception_handler, generic_exception_handler
)
from rate_limiter import RateLimiter
from websocket_relay import WebSocketManager

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("api-gateway")

# ── Service URLs ──────────────────────────────────────────────────────────────
MARKET_DATA_URL  = os.getenv("MARKET_DATA_URL",  "http://market-data:8001")
ORDER_MGMT_URL   = os.getenv("ORDER_MGMT_URL",   "http://order-management:8002")
TRADE_EXEC_URL   = os.getenv("TRADE_EXEC_URL",   "http://trade-execution:8003")
AI_SIGNAL_URL    = os.getenv("AI_SIGNAL_URL",    "http://ai-signal:8004")

# ── FastAPI ───────────────────────────────────────────────────────────────────
app = FastAPI(
    title="Blauplug API Gateway",
    description="Unified API Gateway with JWT auth, RBAC, rate limiting, and WebSocket relay.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

Instrumentator().instrument(app).expose(app, endpoint="/metrics")

# ── Exception Handlers ────────────────────────────────────────────────────────
app.add_exception_handler(AppException, app_exception_handler)
app.add_exception_handler(RequestValidationError, validation_exception_handler)
app.add_exception_handler(Exception, generic_exception_handler)

security         = HTTPBearer()
rate_limiter     = RateLimiter()
ws_manager       = WebSocketManager()


# ── Auth Dependency ───────────────────────────────────────────────────────────
async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    payload = verify_token(credentials.credentials)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return payload


# ── Health ────────────────────────────────────────────────────────────────────
@app.get("/health", tags=["Ops"])
async def health() -> dict:
    return {"status": "healthy", "service": "api-gateway"}


# ── Authentication ────────────────────────────────────────────────────────────
@app.post("/api/auth/login", response_model=TokenResponse, tags=["Auth"])
async def login(payload: LoginRequest) -> TokenResponse:
    """Authenticate a user and return a JWT access token."""
    token_data = create_token(payload.username, payload.password)
    if not token_data:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials.")
    return token_data


@app.post("/api/auth/register", response_model=UserResponse, tags=["Auth"])
async def register(payload: RegisterRequest) -> UserResponse:
    """Register a new user and return user details."""
    user = create_user(payload.username, payload.email, payload.password, payload.role)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Username or email already exists."
        )
    return UserResponse(
        user_id=str(user["id"]),
        username=user["username"],
        email=user["email"],
        role=user["role"],
        created_at=str(user.get("created_at", ""))
    )


@app.post("/api/auth/refresh", tags=["Auth"])
async def refresh_token(user: dict = Depends(get_current_user)) -> TokenResponse:
    """Refresh the JWT access token."""
    token_data = create_token(user["sub"], _refresh=True, existing_payload=user)
    return token_data


@app.get("/api/auth/me", response_model=UserResponse, tags=["Auth"])
async def get_current_user_info(user: dict = Depends(get_current_user)) -> UserResponse:
    """Get current user information."""
    user_data = get_user_by_id(user["user_id"])
    if not user_data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")
    return UserResponse(
        user_id=str(user_data["id"]),
        username=user_data["username"],
        email=user_data["email"],
        role=user_data["role"],
        created_at=str(user_data.get("created_at", ""))
    )


# ── Zerodha OAuth Callback ────────────────────────────────────────────────────
@app.get("/zerodha/login", tags=["Broker Auth"])
async def zerodha_login() -> dict:
    from kiteconnect import KiteConnect
    kite = KiteConnect(api_key=os.getenv("ZERODHA_API_KEY", ""))
    login_url = kite.login_url()
    return {"login_url": login_url}


@app.get("/zerodha/callback", tags=["Broker Auth"])
async def zerodha_callback(request_token: str) -> dict:
    """Exchange Zerodha request_token for access_token and cache in Redis."""
    from kiteconnect import KiteConnect
    import redis
    kite = KiteConnect(api_key=os.getenv("ZERODHA_API_KEY", ""))
    session = kite.generate_session(request_token, api_secret=os.getenv("ZERODHA_API_SECRET", ""))
    access_token = session["access_token"]
    r = redis.Redis(host=os.getenv("REDIS_HOST", "redis"), decode_responses=True)
    r.set("zerodha:access_token", access_token, ex=86400)  # 24-hour expiry
    logger.info("Zerodha access_token refreshed successfully.")
    return {"message": "Zerodha authenticated successfully.", "access_token": access_token}


@app.get("/upstox/callback", tags=["Broker Auth"])
async def upstox_callback(code: str) -> dict:
    """Exchange Upstox OAuth code for access_token and cache in Redis."""
    import redis, httpx
    resp = httpx.post("https://api.upstox.com/v2/login/authorization/token", data={
        "code":          code,
        "client_id":     os.getenv("UPSTOX_CLIENT_ID", ""),
        "client_secret": os.getenv("UPSTOX_CLIENT_SECRET", ""),
        "redirect_uri":  os.getenv("UPSTOX_REDIRECT_URI", ""),
        "grant_type":    "authorization_code",
    })
    access_token = resp.json().get("access_token", "")
    r = redis.Redis(host=os.getenv("REDIS_HOST", "redis"), decode_responses=True)
    r.set("upstox:access_token", access_token, ex=86400)
    logger.info("Upstox access_token refreshed successfully.")
    return {"message": "Upstox authenticated successfully.", "access_token": access_token}


# ── Market Data Proxy ─────────────────────────────────────────────────────────
@app.get("/api/market/info", tags=["Market Data"])
async def market_info(user: dict = Depends(get_current_user)) -> dict:
    async with httpx.AsyncClient() as client:
        resp = await client.get(f"{MARKET_DATA_URL}/info")
        return resp.json()


# ── Orders Proxy ──────────────────────────────────────────────────────────────
@app.post("/api/orders", tags=["Orders"])
async def place_order(
    request: Request,
    user: dict = Depends(get_current_user),
    _: None = Depends(rate_limiter),
) -> dict:
    await rate_limiter.check(request, user)
    body = await request.json()
    body["user_id"] = user["user_id"]
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.post(f"{ORDER_MGMT_URL}/orders", json=body)
        return resp.json()


@app.get("/api/orders", tags=["Orders"])
async def list_orders(user: dict = Depends(get_current_user)) -> dict:
    async with httpx.AsyncClient() as client:
        resp = await client.get(f"{ORDER_MGMT_URL}/orders", params={"user_id": user["user_id"]})
        return resp.json()


@app.get("/api/orders/{order_id}", tags=["Orders"])
async def get_order(order_id: str, user: dict = Depends(get_current_user)) -> dict:
    async with httpx.AsyncClient() as client:
        resp = await client.get(f"{ORDER_MGMT_URL}/orders/{order_id}")
        return resp.json()


@app.delete("/api/orders/{order_id}", tags=["Orders"])
async def cancel_order(order_id: str, user: dict = Depends(get_current_user)) -> dict:
    async with httpx.AsyncClient() as client:
        resp = await client.delete(f"{ORDER_MGMT_URL}/orders/{order_id}")
        return resp.json()


# ── AI Signals Proxy ──────────────────────────────────────────────────────────
@app.get("/api/signals/latest", tags=["AI Signals"])
async def latest_signals(user: dict = Depends(get_current_user)) -> dict:
    async with httpx.AsyncClient() as client:
        resp = await client.get(f"{AI_SIGNAL_URL}/signals/latest")
        return resp.json()


# ── Portfolio Proxy ───────────────────────────────────────────────────────────
@app.get("/api/portfolio", tags=["Portfolio"])
async def get_portfolio(user: dict = Depends(get_current_user)) -> dict:
    """Get user portfolio summary."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(f"{ORDER_MGMT_URL}/portfolio/{user['user_id']}")
        return resp.json()


@app.get("/api/portfolio/holdings", tags=["Portfolio"])
async def get_holdings(user: dict = Depends(get_current_user)) -> list:
    """Get user holdings."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(f"{ORDER_MGMT_URL}/portfolio/{user['user_id']}/holdings")
        return resp.json()


# ── WebSocket — Live Market Data ──────────────────────────────────────────────
@app.websocket("/ws/market")
async def websocket_market_feed(websocket: WebSocket) -> None:
    """WebSocket endpoint broadcasting real-time tick data from Redis pub/sub."""
    await ws_manager.connect(websocket)
    try:
        await ws_manager.stream_market_data(websocket)
    except WebSocketDisconnect:
        ws_manager.disconnect(websocket)
        logger.info("WebSocket client disconnected from /ws/market")


@app.websocket("/ws/portfolio")
async def websocket_portfolio_feed(websocket: WebSocket) -> None:
    """WebSocket endpoint streaming portfolio updates."""
    await ws_manager.connect(websocket)
    try:
        await ws_manager.stream_portfolio_updates(websocket)
    except WebSocketDisconnect:
        ws_manager.disconnect(websocket)


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=int(os.getenv("API_GATEWAY_PORT", 8000)),
        reload=os.getenv("APP_ENV") == "development",
    )
