{{ config(
    materialized='incremental',
    incremental_strategy='append',
    properties={
        'partitioning': "ARRAY['extracted_date']"
    }
) }}

select
    extracted_at,
    -- Partitioning column for Iceberg
    cast(extracted_at as date) as extracted_date,
    product_id,
    seller_id,
    -- Hash key matching dim_categories
    to_hex(
        md5(
            to_utf8(
                concat(
                    coalesce(category_l1, ''),
                    '-',
                    coalesce(category_l2, ''),
                    '-',
                    coalesce(category_l3, ''),
                    '-',
                    coalesce(primary_category_name, '')
                )
            )
        )
    ) as category_key,
    current_price,
    list_price,
    discount,
    discount_rate,
    original_price,
    rating_average,
    review_count,
    order_count,
    favourite_count,
    quantity_sold_count
from {{ ref('stg_tiki__products') }}
