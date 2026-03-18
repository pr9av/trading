# Blauplug Trading Infrastructure Platform

A production-grade real-time trading infrastructure platform for Blauplug Innovation Pvt Ltd. Built with a microservice architecture, Apache Kafka for event streaming, and a Flutter dashboard.

## Architecture

- **API Gateway**: Entry point for JWT auth, RBAC, and service routing.
- **Market Data Service**: Ingests real-time ticks from Zerodha/Upstox/Simulated feeds.
- **Order Management (OMS)**: Manages order lifecycle and broker routing.
- **Trade Execution Engine**: Matches orders and updates portfolios.
- **AI Signal Service**: Generates trading signals using an LSTM model.
- **Flutter Dashboard**: Real-time trading interface.

## Quick Start

### 1. Prerequisites
- Docker & Docker Compose
- Flutter SDK (for dashboard)
- Zerodha/Upstox API Keys (optional, fallback to simulation available)

### 2. Configure Environment
Copy `.env.example` to `.env` and fill in your credentials.
```bash
cp .env.example .env
```

### 3. Run Backend
```bash
docker-compose up -d --build
```

### 4. Verify Services
- API Gateway: http://localhost:8000
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/admin)

### 5. Run Flutter Dashboard
```bash
cd flutter_dashboard
flutter pub get
flutter run
```

## Monitoring & Observability
The platform includes built-in monitoring using Prometheus and Grafana. Dashboards are auto-provisioned for service health, trade latency, and Kafka throughput.

## Security
- **JWT Authentication**: Secured endpoints.
- **RBAC**: Admin/Trader roles.
- **Rate Limiting**: Redis-backed sliding window.
- **Secrets Management**: Credentials stored in environment variables.

---
© 2026 Blauplug Innovation Pvt Ltd.
