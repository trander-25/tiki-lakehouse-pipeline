{{ config(location='s3://lakehouse/dbt_marts/' ~ this.name ~ '.parquet') }}

WITH src AS (
    SELECT DISTINCT
        NULLIF(TRIM(author_name), '') AS author_name
    FROM {{ ref('stg_tiki_products') }}
)

SELECT
    md5(LOWER(author_name)) AS author_sk,
    author_name
FROM src
WHERE author_name IS NOT NULL
