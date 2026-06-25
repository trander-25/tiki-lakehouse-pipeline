import os
import pandas as pd
from trino.dbapi import connect
from dotenv import load_dotenv

load_dotenv()

def main():
    # 1. Establish connection to Trino
    # We use host='localhost', port=8080, user='trino', catalog='iceberg', schema='gold'
    print("Connecting to Trino...")
    try:
        conn = connect(
            host="localhost",
            port=8080,
            user="trino",
            catalog="iceberg",
            schema="gold"
        )
        cur = conn.cursor()
    except Exception as e:
        print(f"Error connecting to Trino: {e}")
        return

    # 2. Ensure target directory exists
    target_dir = "/home/thevinh/repos/tiki-lakehouse-pipeline/tmp_csv"
    os.makedirs(target_dir, exist_ok=True)
    print(f"Target directory: {target_dir}")

    # 3. Retrieve all tables in iceberg.gold schema
    try:
        cur.execute("SHOW TABLES FROM iceberg.gold")
        tables = [row[0] for row in cur.fetchall()]
        print(f"Found tables in gold schema: {tables}")
    except Exception as e:
        print(f"Error listing tables: {e}")
        return

    # 4. Filter for tables starting with dim_ or fct_
    target_tables = [t for t in tables if t.startswith("dim_") or t.startswith("fct_")]
    print(f"Tables to export: {target_tables}")

    if not target_tables:
        print("No dim_ or fct_ tables found. Have you run the dbt models yet?")
        print("Running 'dbt run' might be needed if they are empty or missing.")
        return

    # 5. Export each table to CSV
    for table in target_tables:
        csv_file_path = os.path.join(target_dir, f"{table}.csv")
        print(f"Exporting table '{table}'...")
        try:
            # Query data from Trino
            cur.execute(f"SELECT * FROM iceberg.gold.{table}")
            rows = cur.fetchall()
            
            # Get column names from cursor description
            columns = [desc[0] for desc in cur.description]
            
            # Create DataFrame and save
            df = pd.DataFrame(rows, columns=columns)
            df.to_csv(csv_file_path, index=False)
            print(f"✓ Saved {len(df)} rows to {csv_file_path}")
        except Exception as e:
            print(f"✗ Failed to export '{table}': {e}")

    conn.close()
    print("All exports completed!")

if __name__ == "__main__":
    main()
