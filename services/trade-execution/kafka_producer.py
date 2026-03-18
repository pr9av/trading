"""
Trade Execution Engine — Kafka Event Producer
==============================================
Publishes trade_events and portfolio_updates to Kafka.
Also dual-publishes portfolio updates to Redis pub/sub for real-time
WebSocket streaming to the Flutter dashboard.
"""

import json
import logging
import os
from confluent_kafka import Producer, KafkaException
import redis

logger = logging.getLogger("trade-execution.kafka_producer")

# ── Redis for real-time WebSocket relay ──────────────────────────────────────
_redis_client = redis.Redis(
    host=os.getenv("REDIS_HOST", "redis"),
    port=int(os.getenv("REDIS_PORT", "6379")),
    decode_responses=True,
)


class TradeEventProducer:
    def __init__(self) -> None:
        conf = {
            "bootstrap.servers": os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092"),
            "acks":              "all",
            "retries":           5,
        }
        self._producer        = Producer(conf)
        self._trade_topic     = os.getenv("KAFKA_TOPIC_TRADE_EVENTS",      "trade_events")
        self._portfolio_topic = os.getenv("KAFKA_TOPIC_PORTFOLIO_UPDATES",  "portfolio_updates")

    def publish_trade_event(self, trade: dict) -> None:
        payload = {**trade, "event_type": "TRADE_EXECUTED"}
        self._produce(self._trade_topic, trade["order_id"], payload)
        logger.debug("Published TRADE_EXECUTED for order_id=%s", trade["order_id"])

    def publish_portfolio_update(self, trade: dict) -> None:
        payload = {
            "event_type": "PORTFOLIO_UPDATED",
            "user_id":    trade["user_id"],
            "symbol":     trade["symbol"],
            "side":       trade["side"],
            "quantity":   trade["quantity"],
            "price":      trade["price"],
            "net_value":  trade["net_value"],
            "brokerage":  trade.get("brokerage"),
            "taxes":      trade.get("taxes"),
            "trade_id":   trade["trade_id"],
            "timestamp":  trade["executed_at"],
        }
        self._produce(self._portfolio_topic, trade["user_id"], payload)
        # Also publish to Redis pub/sub for real-time WebSocket relay
        try:
            _redis_client.publish("portfolio_updates", json.dumps(payload))
        except Exception as exc:
            logger.warning("Redis pub/sub error for portfolio_updates: %s", exc)
        logger.debug("Published PORTFOLIO_UPDATED for user_id=%s", trade["user_id"])

    def _produce(self, topic: str, key: str, payload: dict) -> None:
        try:
            self._producer.produce(
                topic=topic,
                key=str(key).encode("utf-8"),
                value=json.dumps(payload).encode("utf-8"),
                on_delivery=self._on_delivery,
            )
            self._producer.poll(0)
        except KafkaException as exc:
            logger.error("Kafka produce error [%s]: %s", topic, exc)

    @staticmethod
    def _on_delivery(err, msg) -> None:
        if err:
            logger.error("Delivery failure [%s]: %s", msg.topic(), err)
