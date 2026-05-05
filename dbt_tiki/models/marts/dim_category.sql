{{ config(location='s3://lakehouse/dbt_marts/' ~ this.name ~ '.parquet') }}

WITH src AS (
    SELECT DISTINCT
        primary_category_id,
        NULLIF(TRIM(primary_category_name), '') AS primary_category_name,
        NULLIF(TRIM(category_l1_name), '') AS category_l1_name,
        NULLIF(TRIM(category_l2_name), '') AS category_l2_name,
        NULLIF(TRIM(category_l3_name), '') AS category_l3_name
    FROM {{ ref('stg_tiki_products') }}
    WHERE primary_category_id IS NOT NULL
)

SELECT
    md5(CAST(primary_category_id AS VARCHAR)) AS category_sk,
    primary_category_id AS category_id,
    primary_category_name,
    category_l1_name,
    category_l2_name,
    category_l3_name
FROM src
