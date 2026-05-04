SELECT
    id AS product_id,
    name AS product_name,
    author_name,
    inventory_status,
    brand_name,
    extracted_at,
    TRY_CAST(price AS integer) AS price,
    TRY_CAST(original_price AS integer) AS original_price,
    TRY_CAST(discount AS integer) AS discount,
    TRY_CAST(discount_rate AS float) AS discount_rate,
    TRY_CAST(rating_average AS float) AS rating_average,
    TRY_CAST(review_count AS integer) AS review_count,
    TRY_CAST(REGEXP_EXTRACT(quantity_sold, '''value'':\s*([0-9]+)', 1) AS integer) AS quantity_sold
FROM READ_PARQUET('s3://raw-data/tiki_products/*.parquet')  