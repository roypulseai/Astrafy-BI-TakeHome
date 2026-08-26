-- Regression test: fail if 2026 order count in mart_orders does not match
-- stg_orders. Avoids hardcoding a specific number; catches drift if the
-- mart silently drops or duplicates rows.

with mart_count as (
    select count(*) as cnt
    from {{ ref('mart_orders') }}
    where order_date >= date('2026-01-01')
      and order_date < date('2027-01-01')
),

source_count as (
    select count(*) as cnt
    from {{ ref('stg_orders') }}
    where order_date >= date('2026-01-01')
      and order_date < date('2027-01-01')
)

select *
from mart_count m
join source_count s on true
where m.cnt != s.cnt
