-- Challenge regression test: fail if any order_id appears more than once in 2026.
-- Validates one row per order grain in mart_orders.

select order_id
from {{ ref('mart_orders') }}
where order_date >= date('2026-01-01')
  and order_date < date('2027-01-01')
group by order_id
having count(*) > 1
