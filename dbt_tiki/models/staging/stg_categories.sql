SELECT DISTINCT
    primary_category_id AS category_id,
    NULLIF(TRIM(primary_category_name), '') AS category_name,
    NULLIF(TRIM(category_l1_name), '') AS category_l1_name,
    NULLIF(TRIM(category_l2_name), '') AS category_l2_name,
    NULLIF(TRIM(category_l3_name), '') AS category_l3_name
FROM {{ ref('stg_products') }}
WHERE primary_category_id IS NOT NULL
