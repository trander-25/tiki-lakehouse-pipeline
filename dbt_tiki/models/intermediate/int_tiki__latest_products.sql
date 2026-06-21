with ranked as (
    select
        product_id,
        product_sku,
        product_name,
        current_price,
        list_price,
        discount,
        discount_rate,
        original_price,
        rating_average,
        review_count,
        order_count,
        favourite_count,
        url_path,
        thumbnail_url,
        seller_id,
        quantity_sold_count,
        category_l1,
        category_l2,
        category_l3,
        primary_category_name,
        seller_type,
        extracted_at,
        row_number()
            over (partition by product_id order by extracted_at desc)
            as rn
    from {{ ref('stg_tiki__products') }}
)

select
    product_id,
    product_sku,
    product_name,
    current_price,
    list_price,
    discount,
    discount_rate,
    original_price,
    rating_average,
    review_count,
    order_count,
    favourite_count,
    url_path,
    thumbnail_url,
    seller_id,
    quantity_sold_count,
    category_l1,
    category_l2,
    category_l3,
    primary_category_name,
    seller_type,
    extracted_at
from ranked
where rn = 1
