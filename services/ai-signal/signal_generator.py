"""
AI Signal Service — Signal Generator
=======================================
Maintains per-symbol rolling windows of tick features,
runs LSTM inference when enough data is buffered, and returns
a signal dict ready for Kafka publishing.
"""

import logging
from collections import defaultdict, deque
from datetime import datetime, timezone

from model import LSTMSignalModel

logger = logging.getLogger("ai-signal.signal_generator")

SEQUENCE_LENGTH  = 60    # ticks per inference window
MIN_CONFIDENCE   = 0.55  # Only emit signals above this confidence threshold
SIGNAL_EVERY_N   = 10    # Emit at most once every N ticks per symbol (throttle)

_tick_counts: dict[str, int] = defaultdict(int)


class SignalGenerator:
    """
    Maintains a rolling buffer per symbol and invokes LSTM inference
    when the buffer reaches SEQUENCE_LENGTH ticks.
    """

    def __init__(self) -> None:
        self.model   = LSTMSignalModel()
        self._buffer: dict[str, deque] = defaultdict(lambda: deque(maxlen=SEQUENCE_LENGTH))

    def process_tick(self, tick: dict) -> dict | None:
        """Update buffer with a new tick and optionally return a signal."""
        symbol = tick.get("symbol")
        if not symbol:
            return None

        features = self._extract_features(tick)
        self._buffer[symbol].append(features)
        _tick_counts[symbol] += 1

        # Wait for full window and throttle signal emissions
        if (len(self._buffer[symbol]) < SEQUENCE_LENGTH or
                _tick_counts[symbol] % SIGNAL_EVERY_N != 0):
            return None

        sequence = list(self._buffer[symbol])
        signal, confidence = self.model.predict(sequence)

        if confidence < MIN_CONFIDENCE:
            logger.debug("Low confidence signal [%s] for %s (%.4f) — skipped",
                         signal, symbol, confidence)
            return None

        result = {
            "symbol":       symbol,
            "signal":       signal,
            "confidence":   confidence,
            "model":        "LSTM-v1",
            "generated_at": datetime.now(tz=timezone.utc).isoformat(),
            "features": {
                "ltp":    tick.get("ltp"),
                "volume": tick.get("volume"),
            },
        }
        logger.info("Signal: %s → %s (conf=%.4f)", symbol, signal, confidence)
        return result

    @staticmethod
    def _extract_features(tick: dict) -> list[float]:
        """Normalize tick fields into a 6-dimensional feature vector."""
        ltp     = float(tick.get("ltp")    or 0)
        open_p  = float(tick.get("open")   or ltp)
        high    = float(tick.get("high")   or ltp)
        low     = float(tick.get("low")    or ltp)
        volume  = float(tick.get("volume") or 0) / 1_000_000   # normalize
        spread  = float(tick.get("ask") or ltp) - float(tick.get("bid") or ltp)

        # Prevent division by zero
        if open_p == 0:
            open_p = ltp or 1.0

        return [
            (ltp - open_p) / open_p,     # return since open
            (high - ltp) / open_p,       # distance to high
            (ltp - low) / open_p,        # distance from low
            (high - low) / open_p,       # range
            volume,                       # normalized volume
            spread / open_p,             # bid-ask spread
        ]
