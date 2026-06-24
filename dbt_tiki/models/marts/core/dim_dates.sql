with date_series as (
    select cast(date_column as date) as date_day
    from
        unnest(
            sequence(date '2025-01-01', date '2028-12-31', interval '1' day)
        ) as t (date_column)
)

select
    cast(format_datetime(cast(date_day as timestamp), 'yyyyMMdd') as integer) as date_key,
    date_day as date_value,
    year(date_day) as year,
    month(date_day) as month,
    day(date_day) as day,
    quarter(date_day) as quarter,
    day_of_week(date_day) as day_of_week_num,
    format_datetime(cast(date_day as timestamp), 'EEEE') as day_name,
    format_datetime(cast(date_day as timestamp), 'MMMM') as month_name
from date_series
