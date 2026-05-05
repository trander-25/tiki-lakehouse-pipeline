{{ config(location='s3://lakehouse/dbt_marts/' ~ this.name ~ '.parquet') }}

SELECT
    {{ dbt_utils.generate_surrogate_key(['author_nk']) }} AS author_sk,
    author_nk,
    author_name
FROM {{ ref('stg_authors') }}

