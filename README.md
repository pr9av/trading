# 🚀 Blauplug Trading Platform V2

A modular, real-time trading infrastructure platform for Blauplug Innovation Pvt Ltd. This repository contains both the high-performance Node.js backend and the modern Flutter analytics dashboard.

## 🏗️ Project Structure

* **`/backend`**: The Node.js Express server handling authentication, market data WebSocket relays, and analytics. [View Backend README](./backend/README.md)
* **`/flutter_dashboard`**: The real-time trading interface built with Flutter & Riverpod.
* **`/database`**: PostgreSQL schema definitions and setup scripts.
* **`simulate.py`**: A Python-based market simulator to pump data for testing.

## 🛠️ Quick Start

### 1. Backend & Database
To run the server and the simulated market data:
1. Navigate to `/backend`, run `npm install`, and configure your `.env`.
2. Run `npm run dev` to start the Node.js api.
3. (In a separate terminal) Run `python simulate.py` to start the live market feed.

### 2. Frontend Dashboard
1. Navigate to `/flutter_dashboard`.
2. Run `flutter pub get`.
3. Run `flutter run -d chrome` (or your preferred device).

---
## 📄 Documentation
* [How it Works](./HOW_IT_WORKS.md) - A simple guide to the system architecture.
* [Backend Setup](./backend/README.md) - Detailed instructions for the server-side.

---
© 2026 Blauplug Innovation Pvt Ltd.
