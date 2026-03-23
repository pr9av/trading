import os
import psycopg2
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")

def check_latest_data():
    if not DATABASE_URL:
        print("[!] DATABASE_URL not found in .env")
        return

    try:
        conn = psycopg2.connect(DATABASE_URL)
        with conn.cursor() as cur:
            print("[*] Fetching latest 10 ticks from 'price_ticks'...\n")
            cur.execute("""
                SELECT time, symbol, ltp, volume 
                FROM price_ticks 
                ORDER BY time DESC 
                LIMIT 10;
            """)
            rows = cur.fetchall()
            
            if not rows:
                print("[!] No data found in market_ticks table.")
                return

            print(f"{'TIME':<25} | {'SYMBOL':<10} | {'LTP':<10} | {'VOLUME':<10}")
            print("-" * 65)
            for row in rows:
                time, symbol, ltp, vol = row
                print(f"{str(time):<25} | {symbol:<10} | {float(ltp):<10.2f} | {vol or 0:<10}")
                
        conn.close()
    except Exception as e:
        print(f"[!] Error: {e}")

if __name__ == "__main__":
    check_latest_data()
