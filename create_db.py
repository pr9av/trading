import os
import psycopg2
from dotenv import load_dotenv

# Load environment variables
load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))

def sync_cloud_db():
    """
    Connects to the cloud PostgreSQL database and initializes 
    the complete schema from database/schema.sql.
    """
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        print("[!] Error: DATABASE_URL not found in .env file.")
        return

    print("[*] Connecting to Cloud Database...")
    
    try:
        # Connect to the database
        conn = psycopg2.connect(db_url)
        conn.autocommit = True
        cur = conn.cursor()
        
        # Read the professional schema.sql file
        schema_path = os.path.join(os.path.dirname(__file__), "database", "schema.sql")
        if not os.path.exists(schema_path):
            print(f"[!] Error: Schema file not found at {schema_path}")
            return

        with open(schema_path, "r") as f:
            schema_sql = f.read()

        print("[*] Executing schema migration...")
        cur.execute(schema_sql)
        
        print("[+] Success: All professional trading tables are synced to Neon Cloud!")
        
        cur.close()
        conn.close()
    except Exception as e:
        print(f"[!] Migration Error: {e}")

if __name__ == "__main__":
    sync_cloud_db()
