import os
import boto3
import io
import pyarrow.parquet as pq
from trino.dbapi import connect
from dotenv import load_dotenv

load_dotenv()


def map_pyarrow_type_to_trino(name, pa_type):
    # Force text, identifier, and JSON columns to VARCHAR
    varchar_cols = {
        "id", "sku", "seller", "brand_name", "badges_new", 
        "visible_impression_info", "quantity_sold", "url_path", 
        "thumbnail_url", "book_cover"
    }
    if name.lower() in varchar_cols:
        return "VARCHAR"
        
    # Map other pyarrow types to Trino SQL types
    type_str = str(pa_type)
    if "int" in type_str:
        return "BIGINT"
    elif "double" in type_str or "float" in type_str:
        return "DOUBLE"
    elif "bool" in type_str:
        return "BOOLEAN"
    else:
        return "VARCHAR"


def main():
    # Connect to S3/MinIO
    endpoint_url = os.getenv("MINIO_ENDPOINT", "http://localhost:9000")
    access_key = os.getenv("MINIO_ACCESS_KEY", "admin")
    secret_key = os.getenv("MINIO_SECRET_KEY", "password")

    s3 = boto3.client(
        "s3",
        endpoint_url=endpoint_url,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        region_name="us-east-1",
    )

    # List files to find the latest parquet file
    print("Listing parquet files in MinIO...")
    res = s3.list_objects_v2(Bucket="raw-data", Prefix="tiki_products/")
    if "Contents" not in res or not res["Contents"]:
        print("No parquet files found in MinIO.")
        return

    # Get the latest key (excluding any folder/empty keys)
    keys = [x["Key"] for x in res["Contents"] if x["Key"].endswith(".parquet")]
    if not keys:
        print("No parquet files found.")
        return

    latest_key = sorted(keys)[-1]
    print(f"Reading schema from latest parquet file: {latest_key}")

    # Download parquet file
    obj = s3.get_object(Bucket="raw-data", Key=latest_key)
    parquet_data = io.BytesIO(obj["Body"].read())

    # Read schema using pyarrow
    table = pq.read_table(parquet_data)

    # Separate normal columns and partition columns
    partition_cols = ["year", "month", "day"]
    normal_columns_def = []
    partition_columns_def = []

    for field in table.schema:
        sql_type = map_pyarrow_type_to_trino(field.name, field.type)
        if field.name in partition_cols:
            partition_columns_def.append(f"  {field.name} {sql_type}")
        else:
            normal_columns_def.append(f"  {field.name} {sql_type}")

    # In Trino Hive partitioned tables, partition columns must be declared at the end of the schema
    all_columns_def = normal_columns_def + partition_columns_def
    columns_sql = ",\n".join(all_columns_def)

    # Connect to Trino
    conn = connect(host="localhost", port=8080, user="trino", catalog="hive")
    cur = conn.cursor()

    # Create schema if not exists
    print("Creating schema hive.tiki_raw...")
    cur.execute("CREATE SCHEMA IF NOT EXISTS hive.tiki_raw WITH (location = 's3://raw-data/')")
    cur.fetchall()

    print("Creating schema iceberg.bronze...")
    cur.execute(
        "CREATE SCHEMA IF NOT EXISTS iceberg.bronze WITH (location = 's3://lakehouse/bronze/')"
    )
    cur.fetchall()

    print("Creating schema iceberg.silver...")
    cur.execute(
        "CREATE SCHEMA IF NOT EXISTS iceberg.silver WITH (location = 's3://lakehouse/silver/')"
    )
    cur.fetchall()

    print("Creating schema iceberg.gold...")
    cur.execute("CREATE SCHEMA IF NOT EXISTS iceberg.gold WITH (location = 's3://lakehouse/gold/')")
    cur.fetchall()

    # Drop table if exists to ensure clean state
    print("Dropping existing table hive.tiki_raw.products_preview...")
    cur.execute("DROP TABLE IF EXISTS hive.tiki_raw.products_preview")
    cur.fetchall()

    # Create table pointing to S3
    create_table_sql = f"""
    CREATE TABLE hive.tiki_raw.products_preview (
    {columns_sql}
    ) WITH (
      format = 'PARQUET',
      external_location = 's3://raw-data/tiki_products/',
      partitioned_by = ARRAY['year', 'month', 'day']
    )
    """

    print("Creating partitioned table hive.tiki_raw.products_preview...")
    cur.execute(create_table_sql)
    cur.fetchall()

    # Sync partition metadata to auto-discover partitions
    print("Syncing partition metadata...")
    cur.execute("CALL hive.system.sync_partition_metadata('tiki_raw', 'products_preview', 'ADD')")
    cur.fetchall()

    print("Successfully setup partitioned external table hive.tiki_raw.products_preview!")

    # Test query
    cur.execute("SELECT count(*) FROM hive.tiki_raw.products_preview")
    res = cur.fetchall()
    print(f"Number of rows in raw table: {res[0][0]}")

    # Show partitions
    cur.execute('SELECT * FROM hive.tiki_raw."products_preview$partitions"')
    partitions = cur.fetchall()
    print("Discovered partitions:")
    for p in partitions:
        print("  ", p)


if __name__ == "__main__":
    main()
