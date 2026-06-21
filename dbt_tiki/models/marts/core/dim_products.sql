with ranked as (
    select
        product_id,
        product_sku,
        product_name,
        url_path,
        thumbnail_url,
        row_number()
            over (partition by product_id order by extracted_at desc)
            as rn
    from {{ ref('stg_tiki__products') }}
)

select
    product_id,
    product_sku,
    product_name,
    url_path,
    thumbnail_url
from ranked
where rn = 1
