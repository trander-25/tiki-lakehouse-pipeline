{{ config(
    materialized='incremental',
    incremental_strategy='append',
    properties={
        'partitioning': "ARRAY['date_key']"
    }
) }}

with new_snapshots as (
    select * from {{ ref('stg_tiki__products') }}
),

{% if is_incremental() %}
    latest_existing as (
        select
            product_id,
            quantity_sold_count as prev_quantity_sold_count
        from (
            select
                product_id,
                cumulative_quantity_sold as quantity_sold_count,
                row_number()
                    over (partition by product_id order by extracted_at desc)
                    as rn
            from {{ this }}
        )
        where rn = 1
    ),
{% endif %}

final as (
    select
        n.extracted_at,
        cast(format_datetime(n.extracted_at, 'yyyyMMdd') as integer) as date_key,
        n.product_id,
        n.seller_id,
        to_hex(
            md5(
                to_utf8(
                    concat(
                        coalesce(n.category_l1, ''),
                        '-',
                        coalesce(n.category_l2, ''),
                        '-',
                        coalesce(n.category_l3, ''),
                        '-',
                        coalesce(n.primary_category_name, '')
                    )
                )
            )
        ) as category_key,
        n.current_price,
        n.list_price,
        n.discount,
        n.discount_rate,
        n.original_price,
        n.rating_average,
        n.review_count,
        n.order_count,
        n.favourite_count,
        n.quantity_sold_count as cumulative_quantity_sold,

        -- Calculate daily quantity sold based on incremental diff
        {% if is_incremental() %}
            coalesce(
                greatest(n.quantity_sold_count - l.prev_quantity_sold_count, 0),
                0
            ) as daily_quantity_sold,
        {% else %}
            coalesce(
                greatest(
                    n.quantity_sold_count - lag(n.quantity_sold_count) over (
                        partition by n.product_id order by n.extracted_at
                    ),
                    0
                ),
                0
            ) as daily_quantity_sold,
        {% endif %}

        -- Calculate daily GMV (Daily Sales * Price)
        {% if is_incremental() %}
            coalesce(
                greatest(n.quantity_sold_count - l.prev_quantity_sold_count, 0),
                0
            ) * n.current_price as daily_gmv,
        {% else %}
            coalesce(
                greatest(
                    n.quantity_sold_count - lag(n.quantity_sold_count) over (
                        partition by n.product_id order by n.extracted_at
                    ),
                    0
                ),
                0
                -- Multiply by current price
            ) * n.current_price as daily_gmv,
        {% endif %}

        -- Strategy helper flag
        n.discount > 0 as is_discounted

    from new_snapshots n
    {% if is_incremental() %}
        left join latest_existing l on n.product_id = l.product_id
    {% endif %}
)

select * from final
