{{ config(location='s3://lakehouse/dbt_marts/' ~ this.name ~ '.parquet') }}

SELECT
    {{ dbt_utils.generate_surrogate_key(['category_id']) }} AS category_sk,
    category_id,
    category_name,
    category_l1_name,
    category_l2_name,
    category_l3_name
FROM {{ ref('stg_categories') }}

