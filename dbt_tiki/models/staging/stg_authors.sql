WITH src AS (
    SELECT DISTINCT
        NULLIF(TRIM(author_name), '') AS author_name
    FROM {{ ref('stg_products') }}
)

SELECT
    LOWER(TRIM(author_name)) AS author_nk,
    author_name
FROM src
WHERE author_name IS NOT NULL
