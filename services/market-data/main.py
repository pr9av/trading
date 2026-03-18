"""
Blauplug Trading Platform — Market Data Ingestion Service
==========================================================
Main application entry point.
"""

import asyncio
import logging
import os

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from prometheus_fastapi_instrumentator import Instrumentator

from broker_factory import BrokerFactory
from kafka_producer import MarketDataProducer

# ── Logging ──────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("market-data")

# ── FastAPI App ───────────────────────────────────────────────────────────────
app = FastAPI(
    title="Blauplug Market Data Ingestion Service",
    description="Ingests real-time tick data from Zerodha / Upstox / Simulated feed and publishes to Kafka.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Prometheus Metrics ────────────────────────────────────────────────────────
Instrumentator().instrument(app).expose(app, endpoint="/metrics")

# ── Background Feed Task ──────────────────────────────────────────────────────
feed_task: asyncio.Task | None = None


@app.on_event("startup")
async def startup_event() -> None:
    global feed_task
    producer = MarketDataProducer()
    broker = BrokerFactory.create(producer)
    feed_task = asyncio.create_task(broker.start())
    logger.info("Market data feed started using broker: %s", os.getenv("ACTIVE_BROKER", "simulated").upper())


@app.on_event("shutdown")
async def shutdown_event() -> None:
    if feed_task:
        feed_task.cancel()
        logger.info("Market data feed stopped.")


# ── Health & Info Endpoints ───────────────────────────────────────────────────
@app.get("/health", tags=["Ops"])
async def health_check() -> dict:
    return {"status": "healthy", "service": "market-data-ingestion"}


@app.get("/info", tags=["Ops"])
async def service_info() -> dict:
    return {
        "service": "market-data-ingestion",
        "version": "1.0.0",
        "active_broker": os.getenv("ACTIVE_BROKER", "simulated"),
        "kafka_bootstrap": os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092"),
    }


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=int(os.getenv("MARKET_DATA_PORT", 8001)),
        reload=os.getenv("APP_ENV", "development") == "development",
    )
