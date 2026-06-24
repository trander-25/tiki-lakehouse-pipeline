with max_partition as (
    -- Trino reads partition metadata directly from Hive Metastore (0 files read from S3)
    select
        max(year) as max_yr,
        max(month) as max_mo,
        max(day) as max_dy
    from {{ source('tiki_raw', 'products_preview') }}
),

max_extracted as (
    -- Scan ONLY the latest partition's files to find the latest crawl timestamp
    select max(p.extracted_at) as max_val
    from {{ source('tiki_raw', 'products_preview') }} p
    join max_partition m
        on
            p.year = m.max_yr
            and p.month = m.max_mo
            and p.day = m.max_dy
),

raw_source as (
    -- Load ONLY the latest file of the latest partition, unless backfill is enabled
    select p.*
    from {{ source('tiki_raw', 'products_preview') }} p
    {% if not var('backfill', false) %}
    join max_partition m
        on
            p.year = m.max_yr
            and p.month = m.max_mo
            and p.day = m.max_dy
    join max_extracted e
        on p.extracted_at = e.max_val
    {% endif %}
),

renamed_and_parsed as (
    select
        id as product_id,
        sku as product_sku,
        name as product_name,
        price as current_price,
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
        seller as seller_name,
        book_cover,

        -- Extract brand or author/publisher for books
        coalesce(
            nullif(brand_name, ''),
            try(
                json_extract_scalar(
                    element_at(
                        filter(
                            cast(json_parse(
                                replace(replace(replace(replace(badges_new, '''', '"'), 'True', 'true'), 'False', 'false'), 'None', 'null')
                            ) as array(json)),
                            x -> json_extract_scalar(x, '$.code') = 'brand_name'
                        ),
                        1
                    ),
                    '$.text'
                )
            )
        ) as brand_name,


        -- Parse quantity sold from string like {'text': 'Đã bán 221', 'value': 221}
        cast(json_extract_scalar(json_parse(
            replace(
                replace(
                    replace(
                        replace(quantity_sold, '''', '"'),
                        'True', 'true'
                    ),
                    'False', 'false'
                ),
                'None', 'null'
            )
        ), '$.value') as integer) as quantity_sold_count,

        -- Parse category and seller info from visible_impression_info field
        json_extract_scalar(json_parse(
            replace(
                replace(
                    replace(
                        replace(visible_impression_info, '''', '"'),
                        'True', 'true'
                    ),
                    'False', 'false'
                ),
                'None', 'null'
            )
        ), '$.amplitude.category_l1_name') as category_l1,

        json_extract_scalar(json_parse(
            replace(
                replace(
                    replace(
                        replace(visible_impression_info, '''', '"'),
                        'True', 'true'
                    ),
                    'False', 'false'
                ),
                'None', 'null'
            )
        ), '$.amplitude.category_l2_name') as category_l2,

        json_extract_scalar(json_parse(
            replace(
                replace(
                    replace(
                        replace(visible_impression_info, '''', '"'),
                        'True', 'true'
                    ),
                    'False', 'false'
                ),
                'None', 'null'
            )
        ), '$.amplitude.category_l3_name') as category_l3,

        json_extract_scalar(json_parse(
            replace(
                replace(
                    replace(
                        replace(visible_impression_info, '''', '"'),
                        'True', 'true'
                    ),
                    'False', 'false'
                ),
                'None', 'null'
            )
        ), '$.amplitude.primary_category_name') as primary_category_name,

        json_extract_scalar(json_parse(
            replace(
                replace(
                    replace(
                        replace(visible_impression_info, '''', '"'),
                        'True', 'true'
                    ),
                    'False', 'false'
                ),
                'None', 'null'
            )
        ), '$.amplitude.seller_type') as seller_type,

        year,
        month,
        day,
        -- Convert timestamp string '20260504_173326' to Timestamp type with precision 6 for Iceberg
        cast(date_parse(extracted_at, '%Y%m%d_%H%i%s') as timestamp(6))
            as extracted_at
    from raw_source
)

select * from renamed_and_parsed
