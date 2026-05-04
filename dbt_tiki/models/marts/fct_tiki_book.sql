{{ config(
    materialized='external',
    location='s3://raw-data/marts/fct_tiki_books.parquet'
) }}

WITH staging AS (
    SELECT * FROM {{ ref('stg_tiki_books') }}
)

SELECT
    product_id,
    product_name,
    author_name,
    price,
    original_price,
    discount,
    discount_rate,
    rating_average,
    review_count,
    inventory_status,
    quantity_sold,
    brand_name,
    STRPTIME(extracted_at, '%Y%m%d_%H%M%S') AS extracted_at_ts
FROM staging