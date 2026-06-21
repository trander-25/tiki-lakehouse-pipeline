import os
import time
from datetime import datetime
from io import BytesIO

import boto3
import pandas as pd
from curl_cffi import requests
from dotenv import load_dotenv

load_dotenv()

# Tiki Book Category ID: 8322
DEFAULT_CATEGORY_ID = 8322
# Tiki 1 page contains about 40 products
DEFAULT_NUM_PAGES = 10  # Default to fetch 10 pages (~400 products)
# Tiki per page limit is 40 products
DEFAULT_LIMIT = 40

MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "http://localhost:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "admin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "password")
MINIO_BUCKET_NAME = "raw-data"

TIKI_BASE_URL = "https://tiki.vn"
TIKI_TIMEOUT_SECONDS = 20


def build_session() -> requests.Session:
    """Build and return a requests session with appropriate headers, cookies, and proxy settings for Tiki API."""
    session = requests.Session(impersonate="chrome124")

    # Set headers to mimic a real browser and include necessary tokens
    session.headers.update(
        {
            "Referer": f"{TIKI_BASE_URL}/",
            "Origin": TIKI_BASE_URL,
            "x-guest-token": os.getenv("TIKI_GUEST_TOKEN", ""),
        }
    )

    # Load cookies from environment variable if available
    if env_cookie := os.getenv("TIKI_COOKIE"):
        cookie_dict = {
            c.split("=", 1)[0].strip(): c.split("=", 1)[1].strip()
            for c in env_cookie.split(";")
            if "=" in c
        }
        session.cookies.update(cookie_dict)

    # Set proxy if specified in environment variable
    proxy = os.getenv("TIKI_PROXY")
    if proxy:
        session.proxies = {"http": proxy, "https": proxy}

    return session


def fetch_tiki_products(
    category_id=DEFAULT_CATEGORY_ID, num_pages=DEFAULT_NUM_PAGES, limit=DEFAULT_LIMIT
):
    """Fetch products from Tiki API for a given category and number of pages.
    Parameters:
        category_id (int): The category ID to fetch products from.
        num_pages (int): The number of pages to fetch.
        limit (int): The number of products per page (max 40 for Tiki).
    Returns:
        list: A list of product data dictionaries.
    """
    session = build_session()
    products = []

    # Loop through the specified number of pages and fetch products
    for page in range(1, num_pages + 1):
        url = f"{TIKI_BASE_URL}/api/personalish/v1/blocks/listings"
        params = {
            "limit": limit,
            "include": "advertisement",
            "aggregations": 2,
            "version": "home-personalized",
            "category": category_id,
            "page": page,
        }
        print(f"Page {page}: Fetching data from Tiki...")

        try:
            response = session.get(url, params=params, timeout=TIKI_TIMEOUT_SECONDS)
            if response.status_code != 200:
                print(f"Non-200 status code received for page {page}: {response.status_code}")
                break

            raw_json = response.json()
            data = raw_json.get("data", [])
            if not data:
                print(f"No more products found on page {page}. Stopping.")
                break

            products.extend(data)
            print(f"Page {page}: Fetched {len(data)} products")

        except requests.exceptions.RequestException as e:
            print(f"Page {page}: Request failed: {e}")
            break

        # Sleep to avoid hitting rate limits
        time.sleep(1)

    return products


def save_to_minio(data):
    """Save the fetched product data to MinIO in Parquet format.
    Parameters:
        data (list): A list of product data dictionaries to save.
    """
    if not data:
        print("No data to save.")
        return

    df = pd.DataFrame(data)

    now = datetime.now()
    year = now.strftime("%Y")
    month = now.strftime("%m")
    day = now.strftime("%d")
    timestamp_str = now.strftime("%Y%m%d_%H%M%S")
    partition_path = f"year={year}/month={month}/day={day}"

    # Add partition columns
    df["year"] = year
    df["month"] = month
    df["day"] = day
    df["extracted_at"] = timestamp_str

    # Convert any columns with dict or list data to string to ensure Parquet compatibility
    for col in df.columns:
        if df[col].apply(lambda x: isinstance(x, (dict, list))).any():
            df[col] = df[col].astype(str)

    # Save preview data locally
    preview_dir = os.path.join("preview_data", partition_path)
    os.makedirs(preview_dir, exist_ok=True)
    preview_path = os.path.join(preview_dir, f"tiki_products_preview_{timestamp_str}.csv")
    df.to_csv(preview_path, index=False)
    print(f"1. Preview data saved to {preview_path}")

    # Convert DataFrame to Parquet format in memory
    parquet_buffer = BytesIO()
    df.to_parquet(parquet_buffer, index=False)
    print(f"2. Data converted to Parquet format in memory.")

    # Initialize MinIO client and upload the Parquet file
    s3_client = boto3.client(
        "s3",
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY,
    )

    file_key = f"tiki_products/{partition_path}/books_{timestamp_str}.parquet"
    print(f"3. Uploading data to MinIO bucket '{MINIO_BUCKET_NAME}' with key '{file_key}'...")

    s3_client.put_object(Bucket=MINIO_BUCKET_NAME, Key=file_key, Body=parquet_buffer.getvalue())
    print(f"4. Data successfully uploaded to MinIO at '{file_key}'.")


if __name__ == "__main__":
    # Fetch products from Tiki and save to MinIO
    products = fetch_tiki_products(num_pages=10)
    print(f"Total products fetched: {len(products)}")
    print("Saving fetched products to MinIO...")
    # Save the fetched products to MinIO
    save_to_minio(products)
