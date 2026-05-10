
{{ config(
    location=get_external_location('dim_authors')
) }}

SELECT
    {{ dbt_utils.generate_surrogate_key(['author_nk']) }} AS author_sk,
    author_nk,
    author_name
FROM {{ ref('stg_authors') }}

