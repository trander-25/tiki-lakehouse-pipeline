import duckdb
from trino.dbapi import connect

DUCKDB_PATH = "tiki.duckdb"
TRINO_HOST = "localhost"
TRINO_PORT = 8082
TRINO_USER = "admin"

def duckdb_to_trino_type(dt):
    dt = dt.upper()
    if dt == "VARCHAR" or dt.startswith("VARCHAR"): return "VARCHAR"
    if dt == "BIGINT": return "BIGINT"
    if dt == "INTEGER": return "INTEGER"
    if dt == "DOUBLE": return "DOUBLE"
    if dt == "BOOLEAN": return "BOOLEAN"
    if dt == "TIMESTAMP": return "TIMESTAMP(3)"
    if dt == "DATE": return "DATE"
    return "VARCHAR" # Fallback

def main():
    con = duckdb.connect(DUCKDB_PATH)
    tables = con.execute("SELECT table_name FROM information_schema.tables WHERE table_schema='main'").fetchall()
    
    trino_conn = connect(
        host=TRINO_HOST,
        port=TRINO_PORT,
        user=TRINO_USER,
        catalog="hive",
        schema="marts"
    )
    trino_cur = trino_conn.cursor()
    
    try:
        trino_cur.execute("CREATE SCHEMA IF NOT EXISTS hive.marts WITH (location = 's3://lakehouse/marts/')")
        trino_cur.fetchall()
    except Exception as e:
        print("Schema creation issue:", e)

    for (table_name,) in tables:
        if not (table_name.startswith('dim_') or table_name.startswith('fct_')):
            continue
            
        columns = con.execute(f"DESCRIBE {table_name}").fetchall()
        col_defs = []
        for col in columns:
            col_name = col[0]
            col_type = duckdb_to_trino_type(col[1])
            col_defs.append(f"{col_name} {col_type}")
            
        ddl = f"""
        CREATE TABLE IF NOT EXISTS hive.marts.{table_name} (
            {', '.join(col_defs)}
        )
        WITH (
            format = 'PARQUET',
            external_location = 's3://lakehouse/marts/{table_name}.parquet'
        )
        """
        print(f"Creating table {table_name}...")
        try:
            trino_cur.execute(f"DROP TABLE IF EXISTS hive.marts.{table_name}")
            trino_cur.fetchall()
            trino_cur.execute(ddl)
            trino_cur.fetchall()
            print(f"Created {table_name} successfully.")
        except Exception as e:
            print(f"Failed to create {table_name}:", e)

if __name__ == "__main__":
    main()
