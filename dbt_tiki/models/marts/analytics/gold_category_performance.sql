with fact as (
    select * from {{ ref('fct_product_snapshots') }}
),

dim_cat as (
    select * from {{ ref('dim_categories') }}
)

select
    f.extracted_date,
    c.category_l1 as parent_category,
    c.category_l2 as sub_category,
    count(distinct f.product_id) as total_products,
    avg(f.current_price) as avg_price,
    sum(f.quantity_sold_count) as total_units_sold,
    avg(f.rating_average) as avg_rating
from fact f
join dim_cat c on f.category_key = c.category_key
group by 1, 2, 3
