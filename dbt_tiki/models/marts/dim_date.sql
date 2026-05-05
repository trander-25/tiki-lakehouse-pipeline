{{ config(location='s3://lakehouse/dbt_marts/' ~ this.name ~ '.parquet') }}

WITH dates AS (
    SELECT DISTINCT extracted_date AS date_day
    FROM {{ ref('stg_tiki_products') }}
    WHERE extracted_date IS NOT NULL
)

SELECT
    CAST(STRFTIME(date_day, '%Y%m%d') AS INTEGER) AS date_key,
    date_day,
    EXTRACT(year FROM date_day) AS year,
    EXTRACT(quarter FROM date_day) AS quarter,
    EXTRACT(month FROM date_day) AS month,
    STRFTIME(date_day, '%Y-%m') AS year_month,
    STRFTIME(date_day, '%A') AS weekday_name
FROM dates
