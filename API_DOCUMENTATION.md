# Blauplug Trading Platform - API Documentation

## Overview

The Blauplug Trading Platform provides a comprehensive REST API for real-time trading operations, portfolio management, order execution, and AI-powered trading signals.

### Base URL
```
http://localhost:8000/api
```

### Authentication
All endpoints (except login/register) require JWT authentication via Bearer token:

```bash
Authorization: Bearer <access_token>
```

---

## Authentication Endpoints

### 1. Register User
**POST** `/auth/register`

Create a new user account.

**Request Body:**
```json
{
  "username": "newuser",
  "email": "user@example.com",
  "password": "SecurePass123",
  "role": "trader"
}
```

**Password Requirements:**
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one digit

**Response (201 Created):**
```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "username": "newuser",
  "email": "user@example.com",
  "role": "trader",
  "created_at": "2026-03-18T10:30:00Z"
}
```

**Error Responses:**
- `409 Conflict`: Username or email already exists
- `422 Unprocessable Entity`: Validation error

---

### 2. Login
**POST** `/auth/login`

Authenticate and receive JWT access token.

**Request Body:**
```json
{
  "username": "trader1",
  "password": "TraderPass123"
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 3600,
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "role": "trader"
}
```

**Error Responses:**
- `401 Unauthorized`: Invalid credentials

---

### 3. Refresh Token
**POST** `/auth/refresh`

Refresh the JWT access token.

**Headers:**
```
Authorization: Bearer <current_token>
```

**Response (200 OK):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 3600,
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "role": "trader"
}
```

---

### 4. Get Current User
**GET** `/auth/me`

Get authenticated user information.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "username": "trader1",
  "email": "trader@example.com",
  "role": "trader",
  "created_at": "2026-03-18T09:15:00Z"
}
```

---

## Order Management Endpoints

### 1. Place Order
**POST** `/orders`

Create and place a new order.

**Request Body:**
```json
{
  "symbol": "RELIANCE",
  "exchange": "NSE",
  "side": "BUY",
  "quantity": 10,
  "order_type": "MARKET",
  "product": "MIS",
  "price": 2850.00
}
```

**Parameters:**
- `symbol`: Stock symbol (e.g., RELIANCE, INFY, TCS)
- `exchange`: NSE, BSE, NCDEX, MCX
- `side`: BUY or SELL
- `order_type`: MARKET, LIMIT, SL, SL-M
- `product`: MIS (intraday), CNC (delivery), NRML (F&O)
- `price`: Required for LIMIT/SL orders
- `trigger_price`: Required for SL/SL-M orders

**Response (201 Created):**
```json
{
  "id": "665e8400-e29b-41d4-a716-446655440111",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "symbol": "RELIANCE",
  "exchange": "NSE",
  "side": "BUY",
  "quantity": 10,
  "price": 2850.00,
  "status": "placed",
  "broker_order_id": "ZRD-123456789",
  "created_at": "2026-03-18T10:30:00Z"
}
```

**Error Responses:**
- `400 Bad Request`: Invalid input
- `422 Unprocessable Entity`: Validation failed
- `429 Too Many Requests`: Rate limit exceeded

---

### 2. List Orders
**GET** `/orders?user_id=<id>&symbol=<symbol>&limit=50`

Retrieve user's orders with optional filters.

**Query Parameters:**
- `user_id` (optional): Filter by user
- `symbol` (optional): Filter by stock symbol
- `limit` (optional, default 50): Max results

**Response (200 OK):**
```json
[
  {
    "id": "665e8400-e29b-41d4-a716-446655440111",
    "symbol": "RELIANCE",
    "side": "BUY",
    "quantity": 10,
    "status": "executed",
    "filled_quantity": 10,
    "avg_fill_price": 2850.50,
    "created_at": "2026-03-18T10:30:00Z"
  }
]
```

---

### 3. Get Order Details
**GET** `/orders/{order_id}`

Retrieve specific order information.

**Response (200 OK):**
```json
{
  "id": "665e8400-e29b-41d4-a716-446655440111",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "symbol": "RELIANCE",
  "exchange": "NSE",
  "side": "BUY",
  "quantity": 10,
  "price": 2850.00,
  "status": "executed",
  "filled_quantity": 10,
  "avg_fill_price": 2850.50,
  "broker_order_id": "ZRD-123456789",
  "placed_at": "2026-03-18T10:30:00Z",
  "executed_at": "2026-03-18T10:30:15Z"
}
```

**Error Responses:**
- `404 Not Found`: Order not found

---

### 4. Cancel Order
**DELETE** `/orders/{order_id}`

Cancel a pending order.

**Response (200 OK):**
```json
{
  "message": "Order 665e8400-e29b-41d4-a716-446655440111 cancelled successfully."
}
```

**Error Responses:**
- `400 Bad Request`: Order cannot be cancelled (already executed/cancelled)
- `404 Not Found`: Order not found

---

## Portfolio Endpoints

### 1. Get Portfolio Summary
**GET** `/portfolio`

Retrieve user's portfolio summary including cash balance and P&L.

**Response (200 OK):**
```json
{
  "portfolio_id": "770e8400-e29b-41d4-a716-446655440000",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "cash_balance": 75000.50,
  "holdings_value": 125490.75,
  "total_value": 200491.25,
  "total_pnl": 5491.25,
  "day_pnl": 2100.50,
  "last_synced_at": "2026-03-18T11:00:00Z"
}
```

---

### 2. Get Holdings
**GET** `/portfolio/holdings`

Retrieve all current stock holdings.

**Response (200 OK):**
```json
[
  {
    "id": "880e8400-e29b-41d4-a716-446655440000",
    "symbol": "RELIANCE",
    "exchange": "NSE",
    "quantity": 10,
    "avg_buy_price": 2800.00,
    "current_price": 2850.00,
    "pnl": 500.00,
    "updated_at": "2026-03-18T11:00:00Z"
  },
  {
    "id": "880e8400-e29b-41d4-a716-446655440001",
    "symbol": "TCS",
    "exchange": "NSE",
    "quantity": 5,
    "avg_buy_price": 3800.00,
    "current_price": 3900.00,
    "pnl": 500.00,
    "updated_at": "2026-03-18T11:00:00Z"
  }
]
```

---

## Market Data Endpoints

### 1. Get Market Info
**GET** `/market/info`

Retrieve market data service information.

**Response (200 OK):**
```json
{
  "service": "market-data-ingestion",
  "version": "1.0.0",
  "active_broker": "zerodha",
  "kafka_bootstrap": "kafka:9092"
}
```

---

## AI Signals Endpoints

### 1. Get Latest Signals
**GET** `/signals/latest`

Retrieve the latest AI trading signals.

**Response (200 OK):**
```json
{
  "signals": [
    {
      "symbol": "RELIANCE",
      "signal": "BUY",
      "confidence": 0.87,
      "model": "LSTM-v1",
      "generated_at": "2026-03-18T11:05:00Z",
      "features": {
        "ltp": 2850.50,
        "volume": 125000
      }
    }
  ]
}
```

---

## WebSocket Endpoints

### 1. Market Data Stream
**WS** `/ws/market`

Real-time market tick data stream.

**Subscribe:**
```javascript
const ws = new WebSocket('ws://localhost:8000/ws/market');
ws.onmessage = (event) => {
  const tick = JSON.parse(event.data);
  console.log(tick);
};
```

**Message Format:**
```json
{
  "symbol": "RELIANCE",
  "ltp": 2850.50,
  "change": 5.50,
  "change_percent": 0.19
}
```

### 2. Portfolio Updates Stream
**WS** `/ws/portfolio`

Real-time portfolio updates stream.

---

## Error Handling

All error responses follow this format:

```json
{
  "error": "Error type",
  "message": "Detailed error message"
}
```

### Common HTTP Status Codes

| Code | Meaning |
|------|---------|
| 200 | OK |
| 201 | Created |
| 400 | Bad Request |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 409 | Conflict |
| 422 | Unprocessable Entity |
| 429 | Too Many Requests |
| 500 | Internal Server Error |

---

## Rate Limiting

Rate limits are enforced per user:
- **Free tier**: 100 requests per minute
- **Premium tier**: 1000 requests per minute

When rate limit is exceeded, you receive:
```
HTTP/1.1 429 Too Many Requests
Retry-After: 30
```

---

## Examples

### Complete Order Placement Flow

```bash
# 1. Register
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "trader1",
    "email": "trader@example.com",
    "password": "SecurePass123"
  }'

# 2. Login
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "trader1",
    "password": "SecurePass123"
  }'

# 3. Place Order
curl -X POST http://localhost:8000/api/orders \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "RELIANCE",
    "side": "BUY",
    "quantity": 10,
    "order_type": "MARKET"
  }'

# 4. Get Portfolio
curl -X GET http://localhost:8000/api/portfolio \
  -H "Authorization: Bearer <access_token>"
```

---

## Support

For API issues or questions:
- Email: support@blauplug.com
- Documentation: https://docs.blauplug.com
- Status Page: https://status.blauplug.com
