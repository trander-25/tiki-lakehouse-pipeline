import os
import boto3

# MinIO Config
MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "http://localhost:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "admin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "password")
MINIO_BUCKET_NAME = "raw-data"

# Local Preview Path
LOCAL_PREVIEW_ROOT = "/home/thevinh/repos/tiki-lakehouse-pipeline/preview_data"

def main():
    print("[*] Connecting to MinIO...")
    s3_client = boto3.client(
        "s3",
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY,
    )
    
    # 1. Clean MinIO objects ending with _080000.parquet
    print("[*] Scanning MinIO bucket raw-data...")
    res = s3_client.list_objects_v2(Bucket=MINIO_BUCKET_NAME, Prefix="tiki_products/")
    
    deleted_minio_count = 0
    if "Contents" in res:
        for obj in res["Contents"]:
            key = obj["Key"]
            if key.endswith("_080000.parquet"):
                print(f"Deleting MinIO: {key}")
                s3_client.delete_object(Bucket=MINIO_BUCKET_NAME, Key=key)
                deleted_minio_count += 1
                
    print(f"[+] Deleted {deleted_minio_count} fake files from MinIO.")
    
    # 2. Clean local preview CSV files ending with _080000.csv
    print("[*] Scanning local preview_data folder...")
    deleted_local_count = 0
    
    if os.path.exists(LOCAL_PREVIEW_ROOT):
        for root, dirs, files in os.walk(LOCAL_PREVIEW_ROOT):
            for file in files:
                if file.endswith("_080000.csv"):
                    file_path = os.path.join(root, file)
                    print(f"Deleting local: {file_path}")
                    os.remove(file_path)
                    deleted_local_count += 1
                    
    print(f"[+] Deleted {deleted_local_count} fake files from local preview_data.")
    print("[🎉] Clean history complete!")

if __name__ == "__main__":
    main()
