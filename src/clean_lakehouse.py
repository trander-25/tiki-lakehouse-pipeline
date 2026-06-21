from trino.dbapi import connect


def main():
    conn = connect(host="localhost", port=8080, user="trino", catalog="iceberg")
    cur = conn.cursor()

    print("Dropping old schemas cascade to clean S3 folders...")
    for schema in ["bronze", "silver", "gold"]:
        print(f"Dropping iceberg.{schema}...")
        try:
            cur.execute(f"DROP SCHEMA IF EXISTS iceberg.{schema} CASCADE")
            cur.fetchall()
        except Exception as e:
            print(f"Error dropping {schema}: {e}")

    print("Lakehouse cleaned successfully!")


if __name__ == "__main__":
    main()
