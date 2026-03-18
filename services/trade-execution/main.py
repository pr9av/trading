"""
Blauplug Trading Platform — Trade Execution Engine
====================================================
Consumes order_events from Kafka, executes or simulates trades,
updates portfolios, and publishes trade/portfolio events back to Kafka.
"""

import asyncio
import json
import logging
import os
import uuid
from datetime import datetime, timezone

import uvicorn
from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator
from confluent_kafka import Consumer, KafkaError

from executor import TradeExecutor
from portfolio import PortfolioManager
from kafka_producer import TradeEventProducer

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("trade-execution")

# ── FastAPI for health/metrics only ──────────────────────────────────────────
app = FastAPI(
    title="Blauplug Trade Execution Engine",
    description="Consumes order events from Kafka and executes trades.",
    version="1.0.0",
)
Instrumentator().instrument(app).expose(app, endpoint="/metrics")


@app.get("/health", tags=["Ops"])
async def health() -> dict:
    return {"status": "healthy", "service": "trade-execution"}


# ── Kafka Consumer Loop ───────────────────────────────────────────────────────
async def run_consumer() -> None:
    conf = {
        "bootstrap.servers": os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092"),
        "group.id":          "trade-execution-group",
        "auto.offset.reset": "earliest",
        "enable.auto.commit": True,
    }
    consumer  = Consumer(conf)
    topic     = os.getenv("KAFKA_TOPIC_ORDER_EVENTS", "order_events")
    consumer.subscribe([topic])

    executor  = TradeExecutor()
    portfolio = PortfolioManager()
    producer  = TradeEventProducer()

    logger.info("Trade Execution Engine consuming from topic: '%s'", topic)

    loop = asyncio.get_event_loop()
    while True:
        msg = await loop.run_in_executor(None, lambda: consumer.poll(1.0))
        if msg is None:
            continue
        if msg.error():
            if msg.error().code() != KafkaError._PARTITION_EOF:
                logger.error("Kafka consumer error: %s", msg.error())
            continue

        try:
            payload = json.loads(msg.value().decode("utf-8"))
            await _process_event(payload, executor, portfolio, producer)
        except Exception as exc:
            logger.error("Failed to process order event: %s", exc, exc_info=True)


async def _process_event(payload: dict, executor, portfolio, producer) -> None:
    event_type = payload.get("event_type", "")

    # Only execute orders that have been placed/validated
    if event_type not in ("ORDER_PLACED", "ORDER_VALIDATED", "ORDER_EXECUTED"):
        return

    order_id = payload.get("order_id")
    logger.info("Processing event=%s order_id=%s symbol=%s",
                event_type, order_id, payload.get("symbol"))

    # Execute the trade
    trade = await executor.execute(payload)
    if not trade:
        logger.warning("Execution returned no trade for order_id=%s", order_id)
        return

    # Update portfolio
    await portfolio.apply_trade(trade)

    # Publish trade and portfolio events to Kafka
    producer.publish_trade_event(trade)
    producer.publish_portfolio_update(trade)

    logger.info("Trade executed: %s | %s %s x%d @ %.2f",
                trade["trade_id"], trade["side"], trade["symbol"],
                trade["quantity"], trade["price"])


@app.on_event("startup")
async def startup() -> None:
    asyncio.create_task(run_consumer())


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=int(os.getenv("TRADE_EXECUTION_PORT", 8003)),
    )
