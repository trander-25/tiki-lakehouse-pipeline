WITH source AS (
    SELECT *
    FROM READ_PARQUET('s3://raw-data/tiki_products/*.parquet')
),

renamed AS (
    SELECT
        TRY_CAST(id AS BIGINT) AS product_id,
        TRY_CAST(sku AS VARCHAR) AS sku,
        TRY_CAST(name AS VARCHAR) AS product_name,
        TRY_CAST(type AS VARCHAR) AS product_type,

        TRY_CAST(url_key AS VARCHAR) AS url_key,
        TRY_CAST(url_path AS VARCHAR) AS url_path,
        TRY_CAST(url_review AS VARCHAR) AS url_review,

        TRY_CAST(author_name AS VARCHAR) AS author_name,
        TRY_CAST(brand_name AS VARCHAR) AS brand_name,
        TRY_CAST(book_cover AS VARCHAR) AS book_cover,

        TRY_CAST(short_description AS VARCHAR) AS short_description,

        TRY_CAST(thumbnail_url AS VARCHAR) AS thumbnail_url,
        TRY_CAST(thumbnail_width AS INTEGER) AS thumbnail_width,
        TRY_CAST(thumbnail_height AS INTEGER) AS thumbnail_height,

        TRY_CAST(inventory_status AS VARCHAR) AS inventory_status,
        TRY_CAST(availability AS VARCHAR) AS availability,

        TRY_CAST(seller_id AS BIGINT) AS seller_id,
        TRY_CAST(seller_product_id AS BIGINT) AS seller_product_id,
        TRY_CAST(seller AS VARCHAR) AS seller_raw,

        TRY_CAST(primary_category_path AS VARCHAR) AS primary_category_path,

        TRY_CAST(price AS BIGINT) AS price,
        TRY_CAST(list_price AS BIGINT) AS list_price,
        TRY_CAST(original_price AS BIGINT) AS original_price,
        TRY_CAST(discount AS BIGINT) AS discount_amount,
        TRY_CAST(discount_rate AS DOUBLE) AS discount_rate,

        TRY_CAST(rating_average AS DOUBLE) AS rating_average,
        TRY_CAST(review_count AS BIGINT) AS review_count,
        TRY_CAST(order_count AS BIGINT) AS order_count,
        TRY_CAST(favourite_count AS BIGINT) AS favourite_count,

        TRY_CAST(product_reco_score AS DOUBLE) AS product_reco_score,

        TRY_CAST(shippable AS BOOLEAN) AS shippable,
        TRY_CAST(has_ebook AS BOOLEAN) AS has_ebook,
        TRY_CAST(is_visible AS BOOLEAN) AS is_visible,

        TRY_CAST(quantity_sold AS VARCHAR) AS quantity_sold_raw,
        TRY_CAST(visible_impression_info AS VARCHAR) AS visible_impression_info_raw,

        TRY_CAST(extracted_at AS VARCHAR) AS extracted_at
    FROM source
),

parsed AS (
    SELECT
        *,
        STRPTIME(extracted_at, '%Y%m%d_%H%M%S') AS extracted_at_ts,
        CAST(STRPTIME(extracted_at, '%Y%m%d_%H%M%S') AS DATE) AS extracted_date,

        -- Primary category id: last segment of a path like "1/2/8322/316/861/67980"
        TRY_CAST(REGEXP_EXTRACT(primary_category_path, '([0-9]+)$', 1) AS BIGINT) AS primary_category_id,

        -- Parse names from `visible_impression_info_raw` (stringified dict with single quotes)
        NULLIF(TRIM(REGEXP_EXTRACT(visible_impression_info_raw, 'category_l1_name[^'']*''([^'']+)''', 1)), '') AS category_l1_name,
        NULLIF(TRIM(REGEXP_EXTRACT(visible_impression_info_raw, 'category_l2_name[^'']*''([^'']+)''', 1)), '') AS category_l2_name,
        NULLIF(TRIM(REGEXP_EXTRACT(visible_impression_info_raw, 'category_l3_name[^'']*''([^'']+)''', 1)), '') AS category_l3_name,
        NULLIF(TRIM(REGEXP_EXTRACT(visible_impression_info_raw, 'primary_category_name[^'']*''([^'']+)''', 1)), '') AS primary_category_name,

        NULLIF(TRIM(REGEXP_EXTRACT(visible_impression_info_raw, 'seller_type[^'']*''([^'']+)''', 1)), '') AS seller_type,

        -- Quantity sold is stored like: {"text": "Đã bán 221", "value": 221}
        -- or as a stringified dict with single quotes.
        TRY_CAST(NULLIF(REGEXP_EXTRACT(quantity_sold_raw, 'value[^0-9]*([0-9]+)', 1), '') AS BIGINT) AS quantity_sold
    FROM renamed
)

SELECT
    product_id,
    sku,
    product_name,
    product_type,

    url_key,
    url_path,
    url_review,

    author_name,
    brand_name,
    book_cover,

    short_description,

    thumbnail_url,
    thumbnail_width,
    thumbnail_height,

    inventory_status,
    availability,

    seller_id,
    seller_product_id,
    seller_type,
    seller_raw,

    primary_category_path,
    primary_category_id,
    category_l1_name,
    category_l2_name,
    category_l3_name,
    primary_category_name,

    price,
    list_price,
    original_price,
    discount_amount,
    discount_rate,

    rating_average,
    review_count,
    order_count,
    favourite_count,

    product_reco_score,

    shippable,
    has_ebook,
    is_visible,

    quantity_sold,
    quantity_sold_raw,

    extracted_at,
    extracted_at_ts,
    extracted_date,

    visible_impression_info_raw
FROM parsed
WHERE product_id IS NOT NULL
