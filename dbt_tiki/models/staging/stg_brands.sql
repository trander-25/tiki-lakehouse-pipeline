WITH src AS (
    SELECT DISTINCT
        NULLIF(TRIM(brand_name), '') AS brand_name
    FROM {{ ref('stg_products') }}
)

SELECT
    LOWER(TRIM(brand_name)) AS brand_nk,
    brand_name
FROM src
WHERE brand_name IS NOT NULL
