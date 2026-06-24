with unique_sellers as (
    select
        seller_id,
        seller_type,
        seller_name,
        row_number()
            over (partition by seller_id order by extracted_at desc)
            as rn
    from {{ ref('stg_tiki__products') }}
    where seller_id is not null
)

select
    seller_id,
    seller_type,
    case
        when seller_id = 1 then 'Tiki Trading'
        else
            coalesce(
                nullif(seller_name, ''), 'Seller ' || cast(seller_id as varchar)
            )
    end as seller_name
from unique_sellers
where rn = 1
