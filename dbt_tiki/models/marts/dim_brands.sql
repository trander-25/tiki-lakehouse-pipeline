{{ config(location='s3://lakehouse/dbt_marts/' ~ this.name ~ '.parquet') }}

SELECT
    {{ dbt_utils.generate_surrogate_key(['brand_nk']) }} AS brand_sk,
    brand_nk,
    brand_name
FROM {{ ref('stg_brands') }}

