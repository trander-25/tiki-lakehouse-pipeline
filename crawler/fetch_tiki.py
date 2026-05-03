import time
import requests
import boto3
import pandas as pd
import os
from dotenv import load_dotenv

load_dotenv()

# Tiki Book Category ID: 8322
DEFAULT_CATEGORY_ID = 8322
# Tiki 1 page contains about 40 products
DEFAULT_NUM_PAGES = 10 # Default to fetch 10 pages (~400 products)
# Tiki per page limit is 40 products
DEFAULT_LIMIT = 40

def fetch_tiki_products(category_id=DEFAULT_CATEGORY_ID, num_pages=DEFAULT_NUM_PAGES, limit=DEFAULT_LIMIT):
    """Fetch products from Tiki API for a given category and number of pages.
    Parameters:
        category_id (int): The category ID to fetch products from.
        num_pages (int): The number of pages to fetch.
        limit (int): The number of products per page (max 40 for Tiki).
    Returns:
        list: A list of product data dictionaries.
    """
    headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'}
    products = []

    for page in range(1, num_pages + 1):
        url = (
            "https://tiki.vn/api/personalish/v1/blocks/listings?"
            f"limit={limit}&include=advertisement&aggregations=2&"
            f"version=home-persionalized&category={category_id}&page={page}"
        )
        print(f"Fetching page {page} from Tiki...")

        try:
            response = requests.get(url, headers=headers, timeout=15)
            if response.status_code == 200:
                data = response.json().get('data', [])
                if not data:
                    print(f"No more products found on page {page}. Stopping.")
                    break
                products.extend(data)
                print(f"Fetched {len(data)} products from page {page}")
        except requests.exceptions.RequestException as e:
            print(f"Request failed for page {page}: {e}")
            break

        # Sleep to avoid hitting rate limits
        time.sleep(1)

    return products


if __name__ == "__main__":
    products = fetch_tiki_products(category_id=DEFAULT_CATEGORY_ID, num_pages=DEFAULT_NUM_PAGES, limit=DEFAULT_LIMIT)