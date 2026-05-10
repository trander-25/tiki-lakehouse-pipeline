
{{ config(
    location=get_external_location('fct_categories_daily')
) }}

WITH base AS (
    SELECT
        date_key,
        category_sk,
        product_sk,
        price,
        discount_rate,
        rating_average,
        review_count,
        favourite_count,
        quantity_sold,
        CASE WHEN inventory_status IS NOT NULL AND LOWER(inventory_status) IN ('available', 'in_stock') THEN 1 ELSE 0 END AS is_available_flag
    FROM {{ ref('fct_product_snapshots') }}
)

SELECT
    date_key,
    category_sk,
    COUNT(DISTINCT product_sk) AS products_cnt,
    AVG(price) AS avg_price,
    AVG(discount_rate) AS avg_discount_rate,
    AVG(rating_average) AS avg_rating,
    SUM(review_count) AS reviews_sum,
    SUM(favourite_count) AS favourites_sum,
    SUM(quantity_sold) AS quantity_sold_sum,
    AVG(is_available_flag) AS available_ratio
FROM base
WHERE category_sk IS NOT NULL
GROUP BY 1, 2
