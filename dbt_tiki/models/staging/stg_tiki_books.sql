SELECT
    product_id,
    product_name,
    author_name,
    inventory_status,
    brand_name,
    extracted_at,
    TRY_CAST(price AS INTEGER) AS price,
    TRY_CAST(original_price AS INTEGER) AS original_price,
    TRY_CAST(discount_amount AS INTEGER) AS discount,
    TRY_CAST(discount_rate AS FLOAT) AS discount_rate,
    TRY_CAST(rating_average AS FLOAT) AS rating_average,
    TRY_CAST(review_count AS INTEGER) AS review_count,
    TRY_CAST(quantity_sold AS INTEGER) AS quantity_sold
FROM {{ ref('stg_tiki_products') }}