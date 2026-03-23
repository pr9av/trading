"""
Blauplug Trading Platform — Simulation Engine
=============================================
Streams randomized price ticks into the 'market_ticks' table 
strictly following the project's data schema.
"""

import os
import time
import random
import requests
from datetime import datetime, timezone
from dotenv import load_dotenv

# Load environment
load_dotenv()

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:pranavb12@localhost:5432/blauplug_trading",
)

# Configuration
INTERVAL_SEC = 0.5  # 2 ticks per second per symbol
BATCH_SIZE = 10     # Batch insert every 10 ticks

# (base_price, volatility)
INSTRUMENTS = {
    "RELIANCE":  (2850.0, 0.012),
    "INFY":      (1740.0, 0.010),
    "TCS":       (3900.0, 0.009),
    "HDFCBANK":  (1650.0, 0.011),
    "ICICIBANK": (1100.0, 0.013),
}

def generate_tick(symbol, current_price, volatility):
    """Generate a realistic randomized price tick."""
    drift = 0.00002
    shock = random.gauss(drift, volatility / 15)
    new_price = round(max(current_price * (1 + shock), 1.0), 2)
    
    return {
        "time": datetime.now(tz=timezone.utc),
        "symbol": symbol,
        "exchange": "NSE",
        "ltp": new_price,
        "open": round(new_price * 0.995, 2),
        "high": round(new_price * 1.008, 2),
        "low": round(new_price * 0.992, 2),
        "close": round(new_price * 0.998, 2),
        "volume": random.randint(50, 5000),
        "oi": random.randint(1000, 50000),
        "bid": round(new_price - 0.05, 2),
        "ask": round(new_price + 0.05, 2),
        "broker_source": "simulation_engine"
    }

import requests

API_URL = f"http://localhost:{os.getenv('API_GATEWAY_PORT', '8000')}/api/ticks"

def run_simulation():
    print(f"[*] Simulation Engine Started (Interval: {INTERVAL_SEC}s)", flush=True)
    print(f"[*] Target API: {API_URL}", flush=True)
    
    prices = {sym: base for sym, (base, _) in INSTRUMENTS.items()}
    
    try:
        while True:
            for symbol, (_, volatility) in INSTRUMENTS.items():
                tick = generate_tick(symbol, prices[symbol], volatility)
                prices[symbol] = tick["ltp"]
                
                # Convert datetime to string for JSON serialization
                tick_payload = tick.copy()
                tick_payload["time"] = tick["time"].isoformat()
                
                try:
                    response = requests.post(API_URL, json=tick_payload, timeout=15.0)
                    if response.status_code != 201:
                        print(f"[!] API Error ({response.status_code}): {response.text}")
                except Exception as e:
                    print(f"[!] HTTP Error: {e}")
                    
            time.sleep(INTERVAL_SEC)
            
    except KeyboardInterrupt:
        print("\n[*] Simulation Stopped.")
    except Exception as e:
        print(f"[!] Error: {e}")

if __name__ == "__main__":
    run_simulation()
