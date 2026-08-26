-- Regression test: fail if monthly 2026 order totals in mart_orders do not
-- match monthly totals in stg_orders. Catches accidental fan-out or grain
-- violations without hardcoding specific counts.

with mart_monthly as (
    select
        extract(month from order_date) as month_num,
        count(*) as monthly_orders
    from {{ ref('mart_orders') }}
    where order_date >= date('2026-01-01')
      and order_date < date('2027-01-01')
    group by 1
),

source_monthly as (
    select
        extract(month from order_date) as month_num,
        count(*) as monthly_orders
    from {{ ref('stg_orders') }}
    where order_date >= date('2026-01-01')
      and order_date < date('2027-01-01')
    group by 1
)

select
    m.month_num,
    m.monthly_orders as mart_count,
    s.monthly_orders as source_count
from mart_monthly m
join source_monthly s using (month_num)
where m.monthly_orders != s.monthly_orders
