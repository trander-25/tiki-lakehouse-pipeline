with unique_sellers as (
    select
        seller_id,
        seller_type,
        row_number()
            over (partition by seller_id order by extracted_at desc)
            as rn
    from {{ ref('stg_tiki__products') }}
    where seller_id is not null
)

select
    seller_id,
    seller_type
from unique_sellers
where rn = 1
