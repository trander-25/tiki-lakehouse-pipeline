with fact as (
    select * from {{ ref('fct_product_snapshots') }}
),

dim_sel as (
    select * from {{ ref('dim_sellers') }}
)

select
    f.date_key as date_key,
    s.seller_id,
    s.seller_name,
    s.seller_type,
    count(distinct f.product_id) as active_sku_count,
    avg(f.discount_rate) as avg_discount_rate,
    sum(f.daily_quantity_sold) as total_units_sold,
    sum(f.daily_gmv) as total_gmv
from fact f
join dim_sel s on f.seller_id = s.seller_id
group by 1, 2, 3, 4
