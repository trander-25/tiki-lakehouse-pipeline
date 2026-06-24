import os
import sys
import ast
import io
import boto3
import numpy as np
import pandas as pd
import pyarrow.parquet as pq
from datetime import datetime, timedelta

# =====================================================================
# ⚙️ CONFIGURATION BLOCK (Tùy chỉnh cấu hình tại đây)
# =====================================================================
BACKFILL_DAYS = 90             # Số ngày lịch sử muốn giả lập
END_DATE = None                # Ngày kết thúc lịch sử. Nếu để None, script tự động lấy Ngày Hôm Nay.
SEED = 42                      # Seed để đảm bảo tạo dữ liệu ngẫu nhiên giống nhau giữa các lần chạy
WRITE_LOCAL_CSV = True         # Có lưu file CSV preview cục bộ hay không

# MinIO Credentials
MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "http://localhost:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "admin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "password")
MINIO_BUCKET_NAME = "raw-data"

# Đường dẫn lưu file CSV preview cục bộ
LOCAL_PREVIEW_ROOT = "/home/thevinh/repos/tiki-lakehouse-pipeline/preview_data"
# =====================================================================

def parse_cumulative_sales(val_str):
    """Phân tích số lượng bán lũy kế từ chuỗi JSON của Tiki API."""
    if pd.isnull(val_str) or not str(val_str).strip():
        return 0
    try:
        # Làm sạch chuỗi json để tương thích với ast.literal_eval
        clean_str = str(val_str).replace("'", '"').replace("True", "true").replace("False", "false").replace("None", "null")
        val_dict = ast.literal_eval(clean_str)
        if isinstance(val_dict, dict):
            return int(val_dict.get('value', 0))
    except Exception:
        # Fallback dùng split nếu JSON lỗi
        try:
            if 'value' in str(val_str):
                parts = str(val_str).split("'value':")
                if len(parts) > 1:
                    return int(parts[1].split('}')[0].strip())
        except:
            pass
    return 0


def main():
    np.random.seed(SEED)
    
    # 1. Kết nối MinIO
    print(f"[*] Connecting to MinIO at {MINIO_ENDPOINT}...")
    s3_client = boto3.client(
        "s3",
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY,
    )
    
    # 2. Tìm tệp cào gần đây nhất (Latest Crawl Template)
    print("[*] Looking for the latest crawled file in MinIO...")
    res = s3_client.list_objects_v2(Bucket=MINIO_BUCKET_NAME, Prefix="tiki_products/")
    if "Contents" not in res or not res["Contents"]:
        print("[!] Error: No crawled parquet files found in MinIO. Please run the crawler first!")
        sys.exit(1)
        
    keys = [x["Key"] for x in res["Contents"] if x["Key"].endswith(".parquet")]
    if not keys:
        print("[!] Error: No parquet files found.")
        sys.exit(1)
        
    # Lọc bỏ các file fake cũ (để tránh lấy nhầm chính file fake làm template)
    clean_keys = [k for k in keys if not k.endswith("_080000.parquet")]
    if not clean_keys:
        # Nếu chỉ có file fake, thì lấy file mới nhất nói chung
        clean_keys = keys
        
    latest_key = sorted(clean_keys)[-1]
    print(f"[+] Auto-detected latest crawl file: s3://{MINIO_BUCKET_NAME}/{latest_key}")
    
    # 3. Đọc dữ liệu mẫu từ MinIO
    obj = s3_client.get_object(Bucket=MINIO_BUCKET_NAME, Key=latest_key)
    parquet_data = io.BytesIO(obj["Body"].read())
    df_temp = pd.read_parquet(parquet_data)
    
    num_products = len(df_temp)
    print(f"[+] Loaded template containing {num_products} products.")
    
    # 4. Thiết lập khoảng thời gian
    end_dt = END_DATE if END_DATE is not None else datetime.now()
    start_dt = end_dt - timedelta(days=BACKFILL_DAYS)
    date_range = [start_dt + timedelta(days=i) for i in range(BACKFILL_DAYS + 1)]
    
    print(f"[*] Generating {len(date_range)} days of history: {start_dt.strftime('%Y-%m-%d')} -> {end_dt.strftime('%Y-%m-%d')}")
    
    # 5. Phân tích sản phẩm để gán hồ sơ bán hàng (Sales Profile)
    # Tự động gán tỉ lệ bán hàng dựa trên ID sản phẩm
    product_ids = df_temp['id'].tolist()
    sales_profiles = []
    
    for pid in product_ids:
        r = np.random.rand()
        if r < 0.12: # 12% bán chạy
            sales_profiles.append(('bestseller', lambda: np.random.randint(4, 16)))
        elif r < 0.50: # 38% bán vừa
            sales_profiles.append(('moderate', lambda: np.random.randint(1, 5)))
        else: # 50% bán chậm
            sales_profiles.append(('slow', lambda: np.random.randint(0, 2)))
            
    # Tạo ma trận tăng trưởng lượng bán ra hàng ngày
    incremental_sales = {}
    for dt in date_range:
        incremental_sales[dt] = {}
        for p_idx, pid in enumerate(product_ids):
            incremental_sales[dt][pid] = sales_profiles[p_idx][1]()
            
    # Tính lượng lũy kế ban đầu tại ngày start_dt
    cumulative_sold = {}
    for p_idx, r in df_temp.iterrows():
        pid = r['id']
        final_cumulative = parse_cumulative_sales(r.get('quantity_sold'))
        total_generated_sales = sum(incremental_sales[dt][pid] for dt in date_range)
        cumulative_sold[pid] = max(0, final_cumulative - total_generated_sales)
        
    # 6. Tạo dữ liệu cho từng ngày và nạp lên MinIO
    for d_idx, dt in enumerate(date_range):
        yr = dt.strftime("%Y")
        mo = dt.strftime("%m")
        dy = dt.strftime("%d")
        timestamp_str = dt.strftime("%Y%m%d_080000") # Giờ mặc định cho các file lịch sử
        partition_path = f"year={yr}/month={mo}/day={dy}"
        
        df_day = df_temp.copy()
        
        # Cập nhật thông tin phân vùng thời gian
        df_day["year"] = yr
        df_day["month"] = mo
        df_day["day"] = dy
        df_day["extracted_at"] = timestamp_str
        
        # Cập nhật số liệu bán và giá
        for idx, row in df_day.iterrows():
            pid = row['id']
            
            # Cập nhật trường quantity_sold
            daily_sale = incremental_sales[dt][pid]
            cumulative_sold[pid] += daily_sale
            df_day.at[idx, 'quantity_sold'] = f"{{'text': 'Đã bán {cumulative_sold[pid]}', 'value': {cumulative_sold[pid]}}}"
            
            # Giả lập biến động giá bán (khuyến mãi)
            orig_price = float(row['list_price']) if pd.notnull(row['list_price']) and float(row['list_price']) > 0 else float(row['price'])
            if orig_price <= 0:
                orig_price = 120000.0
                
            profile = sales_profiles[product_ids.index(pid)][0]
            
            # Cơ hội giảm giá tùy thuộc nhóm sản phẩm
            if profile == 'bestseller':
                discount_prob = 0.55
            elif profile == 'moderate':
                discount_prob = 0.30
            else:
                discount_prob = 0.08
                
            is_disc = np.random.rand() < discount_prob
            if is_disc:
                disc_rate = np.random.randint(10, 45)
                current_price = int(orig_price * (1 - disc_rate / 100.0))
                discount_amt = int(orig_price - current_price)
            else:
                disc_rate = 0
                current_price = int(orig_price)
                discount_amt = 0
                
            df_day.at[idx, 'list_price'] = int(orig_price)
            df_day.at[idx, 'price'] = current_price
            df_day.at[idx, 'original_price'] = int(orig_price)
            df_day.at[idx, 'discount'] = discount_amt
            df_day.at[idx, 'discount_rate'] = disc_rate
            
        # Ép kiểu dữ liệu sang String để tương thích chuẩn với VARCHAR của Trino
        varchar_cols = [
            "id", "sku", "seller", "brand_name", "badges_new", 
            "visible_impression_info", "quantity_sold", "url_path", 
            "thumbnail_url", "book_cover"
        ]
        for col in varchar_cols:
            if col in df_day.columns:
                df_day[col] = df_day[col].fillna("").astype(str)
                
        # Ghi CSV preview cục bộ
        if WRITE_LOCAL_CSV:
            preview_dir = os.path.join(LOCAL_PREVIEW_ROOT, partition_path)
            os.makedirs(preview_dir, exist_ok=True)
            preview_path = os.path.join(preview_dir, f"tiki_products_preview_{timestamp_str}.csv")
            df_day.to_csv(preview_path, index=False)
            
        # Ghi Parquet và đẩy lên MinIO
        parquet_buffer = io.BytesIO()
        df_day.to_parquet(parquet_buffer, index=False)
        
        file_key = f"tiki_products/{partition_path}/books_{timestamp_str}.parquet"
        s3_client.put_object(Bucket=MINIO_BUCKET_NAME, Key=file_key, Body=parquet_buffer.getvalue())
        
        if (d_idx + 1) % 10 == 0 or d_idx == len(date_range) - 1:
            print(f"[+] Processed & Uploaded: {d_idx + 1}/{len(date_range)} days...")
            
    # Delete the original template file from MinIO to prevent schema statistics conflicts (int64 vs varchar)
    if not latest_key.endswith("_080000.parquet"):
        print(f"[*] Deleting original template file to prevent schema mismatch: {latest_key}")
        try:
            s3_client.delete_object(Bucket=MINIO_BUCKET_NAME, Key=latest_key)
        except Exception as e:
            print(f"[!] Warning: Could not delete template file: {e}")
            
    print(f"\n[🎉] SUCCESS! Generated all {len(date_range)} days of history based on the latest crawl.")
    print("Next step: Run `python src/setup_raw_table.py` to sync Hive partitions, then rebuild dbt models.")


if __name__ == "__main__":
    main()
