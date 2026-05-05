{{ config(location='s3://lakehouse/dbt_marts/' ~ this.name ~ '.parquet') }}

WITH base AS (
    SELECT
        seller_id,
        NULLIF(TRIM(seller_type), '') AS seller_type,
        seller_raw,
        extracted_at_ts
    FROM {{ ref('stg_tiki_products') }}
    WHERE seller_id IS NOT NULL
),

ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY seller_id ORDER BY extracted_at_ts DESC) AS rn
    FROM base
)

SELECT
    md5(CAST(seller_id AS VARCHAR)) AS seller_sk,
    seller_id,
    seller_type,
    seller_raw
FROM ranked
WHERE rn = 1
