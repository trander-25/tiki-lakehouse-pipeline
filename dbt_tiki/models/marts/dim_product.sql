{{ config(location='s3://lakehouse/dbt_marts/' ~ this.name ~ '.parquet') }}

WITH base AS (
    SELECT
        product_id,
        sku,
        product_name,
        product_type,
        url_key,
        url_path,
        thumbnail_url,
        thumbnail_width,
        thumbnail_height,
        book_cover,
        has_ebook,
        shippable,
        is_visible,
        brand_name,
        author_name,
        seller_id,
        primary_category_id,
        extracted_at_ts
    FROM {{ ref('stg_tiki_products') }}
),

latest AS (
    SELECT
        product_id,
        MAX(extracted_at_ts) AS latest_extracted_at_ts
    FROM base
    GROUP BY 1
)

SELECT
    md5(CAST(b.product_id AS VARCHAR)) AS product_sk,
    b.product_id,
    b.sku,
    b.product_name,
    b.product_type,
    b.url_key,
    b.url_path,
    b.thumbnail_url,
    b.thumbnail_width,
    b.thumbnail_height,
    b.book_cover,
    b.has_ebook,
    b.shippable,
    b.is_visible,

    CASE WHEN b.brand_name IS NOT NULL AND TRIM(b.brand_name) <> '' THEN md5(LOWER(TRIM(b.brand_name))) END AS brand_sk,
    NULLIF(TRIM(b.brand_name), '') AS brand_name,

    CASE WHEN b.author_name IS NOT NULL AND TRIM(b.author_name) <> '' THEN md5(LOWER(TRIM(b.author_name))) END AS author_sk,
    NULLIF(TRIM(b.author_name), '') AS author_name,

    CASE WHEN b.seller_id IS NOT NULL THEN md5(CAST(b.seller_id AS VARCHAR)) END AS seller_sk,
    b.seller_id,

    CASE WHEN b.primary_category_id IS NOT NULL THEN md5(CAST(b.primary_category_id AS VARCHAR)) END AS category_sk,
    b.primary_category_id AS category_id
FROM base b
JOIN latest l
    ON b.product_id = l.product_id
   AND b.extracted_at_ts = l.latest_extracted_at_ts
