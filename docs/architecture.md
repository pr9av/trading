# Blauplug Trading Infrastructure Architecture

## Overview
The Blauplug Trading Infrastructure is a high-performance, event-driven trading platform designed for real-time market data processing and order execution. It follows a microservices architecture to ensure scalability, fault tolerance, and security.

## Core Components

### 1. API Gateway Layer (FastAPI)
- **Central Entry Point**: Router for all client requests.
- **Authentication**: JWT-based security with RBAC (Admin, Trader).
- **Rate Limiting**: Redis-backed sliding window protection.
- **WebSocket Relay**: Channels real-time market ticks and portfolio updates to clients.

### 2. Market Data Ingestion Service
- **Broker Integration**: Native support for Zerodha Kite Connect and Upstox API.
- **Streaming**: WebSocket-based tick ingestion.
- **Normalization**: Standardizes tick data across different brokers.
- **Producer**: Publishes ticks to Kafka topic `market_ticks`.

### 3. Order Management System (OMS)
- **Order Lifecycle**: Handles creation, validation, and status tracking.
- **Broker Router**: Places orders via Zerodha/Upstox or internal simulation.
- **Persistence**: Relational storage in PostgreSQL.
- **Events**: Publishes order updates to Kafka topic `order_events`.

### 4. Trade Execution Engine
- **Consumer**: Listens to `order_events`.
- **Matching**: Simulated matching against real-time LTP cached in Redis.
- **Portfolio Management**: Updates holdings and cash balances atomically in Redis and PostgreSQL.
- **Events**: Publishes to `trade_events` and `portfolio_updates`.

### 5. AI / ML Signal Module (PyTorch)
- **Model**: LSTM-based time-series predictor.
- **Signal Generation**: Processes live tick streams from Kafka to generate BUY/SELL/HOLD signals.
- **Topic**: Publishes to `ai_signals`.

## Data Flow
1. **Tick Ingestion**: Broker → Market Data Service → Kafka (`market_ticks`).
2. **Order Flow**: Client → API Gateway → OMS → Kafka (`order_events`).
3. **Execution**: Kafka (`order_events`) → Trade Engine → Redis/Postgres → Kafka (`trade_events`).
4. **AI Analysis**: Kafka (`market_ticks`) → AI Signal Service → Kafka (`ai_signals`).
5. **Real-time Feedback**: Kafka → API Gateway (WebSocket) → Flutter Client.

## Infrastructure
- **Message Bus**: Apache Kafka / Zookeeper.
- **Databases**: PostgreSQL (Relational), Redis (Cache/KV), TimescaleDB (Time-series).
- **Monitoring**: Prometheus (Metrics), Grafana (Visualization), ELK (Logs).
- **Orchestration**: Docker Compose (Local), Kubernetes (Cloud).

## Security
- **Transit**: TLS-encrypted connections.
- **Auth**: JWT tokens with short expiry.
- **Broker Keys**: Stored as environment secrets, never committed.
- **Audit Logging**: Comprehensive logging of user actions.
