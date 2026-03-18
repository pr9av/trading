"""
AI Signal Service — Kafka Signal Producer
==========================================
Publishes generated trading signals to the 'ai_signals' Kafka topic.
"""

import json
import logging
import os
from confluent_kafka import Producer, KafkaException

logger = logging.getLogger("ai-signal.kafka_producer")


class SignalProducer:
    def __init__(self) -> None:
        conf = {
            "bootstrap.servers": os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092"),
            "acks":              "1",
            "retries":           3,
        }
        self._producer = Producer(conf)
        self._topic    = os.getenv("KAFKA_TOPIC_AI_SIGNALS", "ai_signals")

    def publish_signal(self, signal: dict) -> None:
        try:
            self._producer.produce(
                topic=self._topic,
                key=signal["symbol"].encode("utf-8"),
                value=json.dumps(signal).encode("utf-8"),
                on_delivery=self._on_delivery,
            )
            self._producer.poll(0)
        except KafkaException as exc:
            logger.error("Signal publish error: %s", exc)

    @staticmethod
    def _on_delivery(err, msg) -> None:
        if err:
            logger.error("Signal delivery failure: %s", err)
