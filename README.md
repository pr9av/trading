# 🚀 Blauplug Trading Platform V2

A modular, real-time trading infrastructure platform for Blauplug Innovation Pvt Ltd. This repository contains both the high-performance Node.js backend and the modern Flutter analytics dashboard.

## 🏗️ Project Structure

* **`/backend`**: The Node.js Express server handling authentication, market data WebSocket relays, and analytics. [View Backend README](./backend/README.md)
* **`/flutter_dashboard`**: The real-time trading interface built with Flutter & Riverpod.
* **`/database`**: PostgreSQL schema definitions and setup scripts.
* **`simulate.py`**: A Python-based market simulator to pump data for testing.

## 🛠️ Quick Start

### 1. Backend & Database Setup
To run the server and the simulated market data:
1. Navigate to `/backend` and run `npm install`.
2. Create your `.env` file (copy `.env.example`) and add your `DATABASE_URL`.
3. **Initialize the Database**: Run `node init_db.js` to automatically apply the schema to your Neon Postgres.
4. **Start the API**: Run `npm run dev`.
5. **Start Market Data**: (In a separate terminal) Run `python simulate.py` from the root folder.

### 🔑 How to get your Credentials

*   **DATABASE_URL (Neon Postgres)**:
    1.  Go to [Neon.tech](https://neon.tech/) and create a free account.
    2.  Create a project named `trading-platform`.
    3.  Copy the **Connection String** from the dashboard. Ensure it starts with `postgres://`.
    4.  Paste this into your `.env` file as `DATABASE_URL`.
*   **JWT_SECRET**:
    1.  This can be any random string (e.g., `my_secret_key_123`).
    2.  It is used to sign your login tokens.
*   **PORT**:
    1.  Default is `8000`. Ensure this matches your frontend `api_config.dart`.

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
