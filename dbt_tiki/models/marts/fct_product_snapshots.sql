{{ config(location='s3://lakehouse/dbt_marts/' ~ this.name ~ '.parquet') }}
  
WITH src AS (
    SELECT *
    FROM {{ ref('stg_products') }}
    WHERE extracted_at_ts IS NOT NULL
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

dim_categories AS (
    SELECT category_id, category_sk
    FROM {{ ref('dim_categories') }}
),

dim_sellers AS (
    SELECT seller_id, seller_sk
    FROM {{ ref('dim_sellers') }}
),

dim_dates AS (
    SELECT date_day, date_key
    FROM {{ ref('dim_dates') }}
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['src.product_id', 'src.extracted_at_ts']) }} AS snapshot_sk,

    dp.product_sk,
    dd.date_key,
    db.brand_sk,
    da.author_sk,
    dc.category_sk,
    ds.seller_sk,

    -- Snapshot timestamps
    src.extracted_at_ts,
    src.extracted_date,

    -- Measures
    src.price,
    src.list_price,
    src.original_price,
    src.discount_amount,
    src.discount_rate,

    CASE
        WHEN src.original_price IS NOT NULL AND src.price IS NOT NULL THEN GREATEST(src.original_price - src.price, 0)
        ELSE NULL
    END AS discount_amount_calc,

    src.rating_average,
    src.review_count,
    src.order_count,
    src.favourite_count,
    src.quantity_sold,
    src.product_reco_score,

    -- Ops / availability attributes at snapshot time
    src.inventory_status,
    src.availability,
    src.shippable,
    src.has_ebook,
    src.is_visible
FROM src
LEFT JOIN dim_products dp
    ON src.product_id = dp.product_id
LEFT JOIN dim_dates dd
    ON src.extracted_date = dd.date_day
LEFT JOIN dim_brands db
    ON LOWER(TRIM(src.brand_name)) = db.brand_nk
LEFT JOIN dim_authors da
    ON LOWER(TRIM(src.author_name)) = da.author_nk
LEFT JOIN dim_categories dc
    ON src.primary_category_id = dc.category_id
LEFT JOIN dim_sellers ds
    ON src.seller_id = ds.seller_id

