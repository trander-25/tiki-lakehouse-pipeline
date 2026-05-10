
{{ config(
    location=get_external_location('dim_sellers')
) }}

SELECT
    {{ dbt_utils.generate_surrogate_key(['seller_id']) }} AS seller_sk,
    seller_id,
    seller_type,
    seller_raw
FROM {{ ref('stg_sellers') }}

