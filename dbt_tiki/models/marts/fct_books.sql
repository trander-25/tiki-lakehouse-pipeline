
{{ config(
    location=get_external_location('fct_books')
) }}

WITH src AS (
    SELECT
        *,
        STRPTIME(extracted_at, '%Y%m%d_%H%M%S') AS extracted_at_ts,
        CAST(STRPTIME(extracted_at, '%Y%m%d_%H%M%S') AS DATE) AS extracted_date
    FROM {{ ref('stg_books') }}
),

dim_products AS (
    SELECT product_id, product_sk
    FROM {{ ref('dim_products') }}
),

dim_brands AS (
    SELECT brand_nk, brand_sk
    FROM {{ ref('dim_brands') }}
),

dim_authors AS (
    SELECT author_nk, author_sk
    FROM {{ ref('dim_authors') }}
),

dim_dates AS (
    SELECT date_day, date_key
    FROM {{ ref('dim_dates') }}
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['dp.product_sk', 'src.extracted_at_ts']) }} AS book_snapshot_sk,
    dp.product_sk,
    dd.date_key,
    db.brand_sk,
    da.author_sk,

    -- Measures
    src.price,
    src.original_price,
    src.discount,
    src.discount_rate,
    src.rating_average,
    src.review_count,
    src.quantity_sold,

    -- Snapshot attributes
    src.inventory_status,
    src.extracted_at_ts
FROM src
LEFT JOIN dim_products dp
    ON src.product_id = dp.product_id
LEFT JOIN dim_dates dd
    ON src.extracted_date = dd.date_day
LEFT JOIN dim_brands db
    ON LOWER(TRIM(src.brand_name)) = db.brand_nk
LEFT JOIN dim_authors da
    ON LOWER(TRIM(src.author_name)) = da.author_nk
