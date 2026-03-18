"""
Kafka Producer — Market Data Service
======================================
Publishes normalized MarketTick objects to the 'market_ticks' Kafka topic.
Dual-publishes to Redis pub/sub for real-time WebSocket relay and caches
the latest LTP per symbol in Redis for the trade execution price lookup.
"""

import json
import logging
import os
from confluent_kafka import Producer, KafkaException
import redis

from normalizer import MarketTick

logger = logging.getLogger("market-data.kafka_producer")

# ── Redis client for pub/sub + LTP cache ─────────────────────────────────────
_redis_client = redis.Redis(
    host=os.getenv("REDIS_HOST", "redis"),
    port=int(os.getenv("REDIS_PORT", "6379")),
    decode_responses=True,
)


class MarketDataProducer:
    """Thread-safe Kafka producer for market tick events."""

    def __init__(self) -> None:
        conf = {
            "bootstrap.servers": os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092"),
            "acks":              "all",
            "retries":           5,
            "retry.backoff.ms":  200,
            "compression.type":  "lz4",
            "linger.ms":         10,
            "batch.num.messages": 1000,
        }
        self._producer  = Producer(conf)
        self._topic     = os.getenv("KAFKA_TOPIC_MARKET_TICKS", "market_ticks")
        self._published = 0

    def publish(self, tick: MarketTick) -> None:
        """Publish a single MarketTick to Kafka and Redis pub/sub."""
        payload_json = json.dumps(tick.to_dict())
        try:
            # 1. Kafka — durable event stream
            self._producer.produce(
                topic=self._topic,
                key=tick.symbol.encode("utf-8"),
                value=payload_json.encode("utf-8"),
                on_delivery=self._on_delivery,
            )
            self._producer.poll(0)
            self._published += 1

            if self._published % 500 == 0:
                logger.info("Published %d ticks to Kafka topic '%s'", self._published, self._topic)

        except KafkaException as exc:
            logger.error("Kafka publish error for %s: %s", tick.symbol, exc)
        except BufferError:
            logger.warning("Kafka local buffer full — flushing…")
            self._producer.flush(timeout=2)
            self.publish(tick)  # retry after flush

        try:
            # 2. Redis pub/sub — real-time WebSocket relay feed
            _redis_client.publish("market_ticks", payload_json)
            # 3. Cache latest LTP for trade executor price lookups
            _redis_client.set(f"ltp:{tick.symbol}", str(tick.ltp), ex=300)
        except Exception as exc:
            # Redis failure must never block the market feed
            logger.warning("Redis publish/cache error for %s: %s", tick.symbol, exc)

    def flush(self) -> None:
        self._producer.flush()

    @staticmethod
    def _on_delivery(err, msg) -> None:
        if err:
            logger.error("Delivery failure [topic=%s, key=%s]: %s",
                         msg.topic(), msg.key(), err)
