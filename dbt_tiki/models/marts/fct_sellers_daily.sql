{{ config(location='s3://lakehouse/dbt_marts/' ~ this.name ~ '.parquet') }}

WITH base AS (
    SELECT
        date_key,
        seller_sk,
        price,
        discount_rate,
        rating_average,
        review_count,
        favourite_count,
        quantity_sold,
        product_sk
    FROM {{ ref('fct_product_snapshots') }}
)

SELECT
    date_key,
    seller_sk,
    COUNT(DISTINCT product_sk) AS products_cnt,
    AVG(price) AS avg_price,
    AVG(discount_rate) AS avg_discount_rate,
    AVG(rating_average) AS avg_rating,
    SUM(review_count) AS reviews_sum,
    SUM(favourite_count) AS favourites_sum,
    SUM(quantity_sold) AS quantity_sold_sum
FROM base
WHERE seller_sk IS NOT NULL
GROUP BY 1, 2
