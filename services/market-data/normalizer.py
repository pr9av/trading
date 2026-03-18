"""
Market Tick Normalizer
======================
Converts broker-specific tick schemas into a unified MarketTick dataclass.
All downstream services consume only the normalized format.
"""

from dataclasses import dataclass, asdict
from typing import Optional
from datetime import datetime, timezone


@dataclass
class MarketTick:
    time:          str
    symbol:        str
    exchange:      str
    ltp:           float
    open:          Optional[float] = None
    high:          Optional[float] = None
    low:           Optional[float] = None
    close:         Optional[float] = None
    volume:        Optional[int]   = None
    oi:            Optional[int]   = None
    bid:           Optional[float] = None
    ask:           Optional[float] = None
    broker_source: str             = "unknown"

    def to_dict(self) -> dict:
        return asdict(self)


# ── Zerodha ───────────────────────────────────────────────────────────────────

def normalize_zerodha_tick(raw: dict) -> MarketTick:
    """
    Normalize a KiteTicker FULL-mode tick into MarketTick.
    KiteTicker delivers timestamps as Unix epoch in milliseconds.
    """
    ts = raw.get("timestamp") or raw.get("last_trade_time")
    if ts:
        time_str = datetime.fromtimestamp(ts, tz=timezone.utc).isoformat()
    else:
        time_str = datetime.now(tz=timezone.utc).isoformat()

    ohlc = raw.get("ohlc", {})
    depth = raw.get("depth", {})
    best_bid = depth.get("buy",  [{}])[0].get("price")
    best_ask = depth.get("sell", [{}])[0].get("price")

    return MarketTick(
        time=time_str,
        symbol=str(raw.get("tradingsymbol", raw.get("instrument_token", "UNKNOWN"))),
        exchange=raw.get("exchange", "NSE"),
        ltp=float(raw.get("last_price", 0)),
        open=float(ohlc.get("open", 0)) or None,
        high=float(ohlc.get("high", 0)) or None,
        low=float(ohlc.get("low",  0)) or None,
        close=float(ohlc.get("close", 0)) or None,
        volume=int(raw.get("volume", 0)) or None,
        oi=int(raw.get("oi", 0)) or None,
        bid=float(best_bid) if best_bid else None,
        ask=float(best_ask) if best_ask else None,
        broker_source="zerodha",
    )


# ── Upstox ────────────────────────────────────────────────────────────────────

def normalize_upstox_tick(raw: dict) -> MarketTick:
    """
    Normalize Upstox MarketDataStreamer FULL feed message into MarketTick.
    """
    feeds = raw.get("feeds", {})
    symbol_key = list(feeds.keys())[0] if feeds else "UNKNOWN"
    data = feeds.get(symbol_key, {}).get("ff", {}).get("marketFF", {})

    ltpc     = data.get("ltpc", {})
    ohlc_d   = data.get("ohlc",  {})
    mbp      = data.get("marketLevel", {}).get("bidAskQuote", [])
    best_bid = mbp[0].get("bp") if mbp else None
    best_ask = mbp[0].get("ap") if mbp else None

    # Instrument key format: "NSE_EQ|INE002A01018" → symbol is "INE002A01018"
    parts    = symbol_key.split("|")
    exchange = parts[0] if len(parts) == 2 else "NSE"
    symbol   = parts[1] if len(parts) == 2 else symbol_key

    return MarketTick(
        time=datetime.now(tz=timezone.utc).isoformat(),
        symbol=symbol,
        exchange=exchange,
        ltp=float(ltpc.get("ltp", 0)),
        open=float(ohlc_d.get("open", 0)) or None,
        high=float(ohlc_d.get("high", 0)) or None,
        low=float(ohlc_d.get("low",  0)) or None,
        close=float(ohlc_d.get("close", 0)) or None,
        volume=int(data.get("tradedVolume", 0)) or None,
        oi=int(data.get("oi", 0)) or None,
        bid=float(best_bid) if best_bid else None,
        ask=float(best_ask) if best_ask else None,
        broker_source="upstox",
    )
