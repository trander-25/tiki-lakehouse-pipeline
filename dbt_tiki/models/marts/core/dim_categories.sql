with unique_categories as (
    select distinct
        category_l1,
        category_l2,
        category_l3,
        primary_category_name
    from {{ ref('stg_tiki__products') }}
    where category_l1 is not null
)

select
    -- Generate hash key for category combination compliant with Trino/Iceberg
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
    category_l1,
    category_l2,
    category_l3,
    primary_category_name
from unique_categories
