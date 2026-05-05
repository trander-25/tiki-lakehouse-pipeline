{{ config(location='s3://lakehouse/dbt_marts/' ~ this.name ~ '.parquet') }}

WITH src AS (
    SELECT DISTINCT
        NULLIF(TRIM(brand_name), '') AS brand_name
    FROM {{ ref('stg_tiki_products') }}
)

SELECT
    md5(LOWER(brand_name)) AS brand_sk,
    brand_name
FROM src
WHERE brand_name IS NOT NULL
