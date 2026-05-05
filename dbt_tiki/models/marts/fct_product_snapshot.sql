{{ config(location='s3://lakehouse/dbt_marts/' ~ this.name ~ '.parquet') }}

WITH src AS (
    SELECT *
    FROM {{ ref('stg_tiki_products') }}
    WHERE extracted_at_ts IS NOT NULL
)

SELECT
    md5(CAST(product_id AS VARCHAR) || '|' || CAST(extracted_at_ts AS VARCHAR)) AS snapshot_sk,

    md5(CAST(product_id AS VARCHAR)) AS product_sk,
    CAST(STRFTIME(extracted_date, '%Y%m%d') AS INTEGER) AS date_key,

    CASE WHEN brand_name IS NOT NULL AND TRIM(brand_name) <> '' THEN md5(LOWER(TRIM(brand_name))) END AS brand_sk,
    CASE WHEN author_name IS NOT NULL AND TRIM(author_name) <> '' THEN md5(LOWER(TRIM(author_name))) END AS author_sk,
    CASE WHEN primary_category_id IS NOT NULL THEN md5(CAST(primary_category_id AS VARCHAR)) END AS category_sk,
    CASE WHEN seller_id IS NOT NULL THEN md5(CAST(seller_id AS VARCHAR)) END AS seller_sk,

    -- Natural keys (keep for debugging / lineage)
    product_id,
    sku,
    seller_id,
    primary_category_id AS category_id,

    -- Snapshot timestamps
    extracted_at_ts,
    extracted_date,

    -- Measures
    price,
    list_price,
    original_price,
    discount_amount,
    discount_rate,

    CASE
        WHEN original_price IS NOT NULL AND price IS NOT NULL THEN GREATEST(original_price - price, 0)
        ELSE NULL
    END AS discount_amount_calc,

    rating_average,
    review_count,
    order_count,
    favourite_count,
    quantity_sold,
    product_reco_score,

    -- Ops / availability attributes at snapshot time
    inventory_status,
    availability,
    shippable,
    has_ebook,
    is_visible
FROM src
