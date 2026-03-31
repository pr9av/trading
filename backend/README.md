# 🧠 Blauplug Trading Backend & Database

This repository contains the backend infrastructure for the Blauplug Trading Platform. It is designed to handle market ticks, candle generation, authentication, and portfolio analytics.

## 🚀 Quick Start (New Device)

If you are cloning this project onto a new machine, follow these exact steps to get the server running.

### 1. Prerequisites
* **Node.js**: (Version 16 or higher)
* **Git**: To clone the repository.
* **Database**: You need access to the Neon Postgres database (or a local PostgreSQL instance).

### 2. Installation
Navigate into the `backend` directory and install the necessary dependencies:

```bash
cd backend
npm install
```

### 3. Environment Configuration
The `.env` file is excluded from Git for security. You **MUST** create a new one in the `backend/` folder:

1. Create a file named `.env` inside the `backend` directory.
2. Add your database connection string and desired port:

```env
DATABASE_URL=postgres://[user]:[password]@[host]/[dbname]?sslmode=require
PORT=8000
JWT_SECRET=your_super_secret_key_change_this
```

### 4. Running the Server

**Development Mode (with auto-reload):**
```bash
npm run dev
```

**Production Mode:**
```bash
npm start
```

## 💾 Database Logic
The backend connects to a **Neon PostgreSQL** database. 

* **State**: Since the database is in the cloud, any device running this backend with the same `DATABASE_URL` will see the exact same users, market prices, and AI signals.
* **Schema**: If you need to set up a new database, run the SQL scripts found in the `database/` folder of this repository.

## 📡 API Endpoints
* `POST /api/auth/register` - Create a new trader account.
* `POST /api/auth/login` - Secure login and token generation.
* `GET /api/ticks` - Stream live market data.
* `GET /api/analytics/pnl` - Fetch trade performance.

---
*Maintained by Blauplug Innovation Pvt Ltd.*
