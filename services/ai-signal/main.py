"""
Blauplug Trading Platform — AI / Quantitative Signal Service
=============================================================
Consumes market_ticks from Kafka, runs LSTM inference, and publishes
trading signals (BUY / SELL / HOLD) to the ai_signals Kafka topic.
"""

import asyncio
import json
import logging
import os

import uvicorn
from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator
from confluent_kafka import Consumer, KafkaError

from model import LSTMSignalModel
from signal_generator import SignalGenerator
from kafka_producer import SignalProducer

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("ai-signal")

app = FastAPI(
    title="Blauplug AI Signal Service",
    description="LSTM-driven trading signal generation from live market tick streams.",
    version="1.0.0",
)
Instrumentator().instrument(app).expose(app, endpoint="/metrics")

signal_generator: SignalGenerator = None
signal_cache: list = []


@app.get("/health", tags=["Ops"])
async def health() -> dict:
    return {"status": "healthy", "service": "ai-signal"}


@app.get("/signals/latest", tags=["Signals"])
async def latest_signals() -> dict:
    """Return the last 20 generated AI trading signals."""
    return {"signals": signal_cache[-20:]}


async def run_consumer() -> None:
    global signal_generator, signal_cache
    signal_generator = SignalGenerator()
    producer         = SignalProducer()

    conf = {
        "bootstrap.servers": os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092"),
        "group.id":          "ai-signal-group",
        "auto.offset.reset": "latest",
    }
    consumer = Consumer(conf)
    consumer.subscribe([os.getenv("KAFKA_TOPIC_MARKET_TICKS", "market_ticks")])

    logger.info("AI Signal Service consuming from 'market_ticks'…")
    loop = asyncio.get_event_loop()

    while True:
        msg = await loop.run_in_executor(None, lambda: consumer.poll(1.0))
        if msg is None:
            continue
        if msg.error():
            if msg.error().code() != KafkaError._PARTITION_EOF:
                logger.error("Kafka error: %s", msg.error())
            continue

        try:
            tick = json.loads(msg.value().decode("utf-8"))
            result = signal_generator.process_tick(tick)
            if result:
                producer.publish_signal(result)
                signal_cache.append(result)
                if len(signal_cache) > 500:
                    signal_cache = signal_cache[-500:]
        except Exception as exc:
            logger.error("Signal generation error: %s", exc, exc_info=True)


@app.on_event("startup")
async def startup() -> None:
    asyncio.create_task(run_consumer())


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=int(os.getenv("AI_SIGNAL_PORT", 8004)),
    )
