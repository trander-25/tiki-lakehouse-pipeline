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
        primary_category_id AS category_id,
        extracted_at_ts
    FROM {{ ref('stg_products') }}
),

latest AS (
    SELECT
        product_id,
        MAX(extracted_at_ts) AS latest_extracted_at_ts
    FROM base
    GROUP BY 1
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['b.product_id']) }} AS product_sk,
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
    b.brand_name,
    b.author_name,
    b.seller_id,
    b.category_id
FROM base b
INNER JOIN latest l
    ON b.product_id = l.product_id
   AND b.extracted_at_ts = l.latest_extracted_at_ts

