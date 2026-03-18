"""
OMS — Kafka Event Producer
============================
Publishes order lifecycle events to the 'order_events' Kafka topic.
"""

import json
import logging
import os
import uuid
from datetime import datetime

from confluent_kafka import Producer, KafkaException

logger = logging.getLogger("order-management.kafka_producer")


def _serialize(obj):
    if isinstance(obj, (uuid.UUID,)):
        return str(obj)
    if isinstance(obj, datetime):
        return obj.isoformat()
    raise TypeError(f"Type {type(obj)} is not JSON serializable")


class OrderEventProducer:
    def __init__(self) -> None:
        conf = {
            "bootstrap.servers": os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092"),
            "acks":              "all",
            "retries":           5,
        }
        self._producer = Producer(conf)
        self._topic    = os.getenv("KAFKA_TOPIC_ORDER_EVENTS", "order_events")

    def publish_order_event(self, order, event_type: str) -> None:
        """Publish an order lifecycle event keyed by order_id."""
        payload = {
            "event_type": event_type,
            "order_id":   str(order.id),
            "user_id":    str(order.user_id),
            "symbol":     order.symbol,
            "exchange":   order.exchange,
            "side":       order.side,
            "order_type": order.order_type,
            "product":    order.product,
            "quantity":   order.quantity,
            "price":      float(order.price) if order.price else None,
            "status":     order.status,
            "broker":     order.broker,
            "broker_order_id": order.broker_order_id,
            "timestamp":  datetime.utcnow().isoformat(),
        }
        try:
            self._producer.produce(
                topic=self._topic,
                key=str(order.id).encode("utf-8"),
                value=json.dumps(payload, default=_serialize).encode("utf-8"),
                on_delivery=self._on_delivery,
            )
            self._producer.poll(0)
        except KafkaException as exc:
            logger.error("Kafka publish error (order_events): %s", exc)

    @staticmethod
    def _on_delivery(err, msg) -> None:
        if err:
            logger.error("Order event delivery failure: %s", err)
        else:
            logger.debug("Order event delivered → %s [p=%d, o=%d]",
                         msg.topic(), msg.partition(), msg.offset())
