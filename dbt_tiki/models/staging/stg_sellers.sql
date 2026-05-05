WITH base AS (
    SELECT
        seller_id,
        NULLIF(TRIM(seller_type), '') AS seller_type,
        seller_raw,
        extracted_at_ts
    FROM {{ ref('stg_products') }}
    WHERE seller_id IS NOT NULL
),

ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY seller_id ORDER BY extracted_at_ts DESC) AS rn
    FROM base
)

SELECT
    seller_id,
    seller_type,
    seller_raw,
    extracted_at_ts
FROM ranked
WHERE rn = 1
