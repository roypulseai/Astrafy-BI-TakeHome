-- Exercise 1: Total orders in 2026.
select count(*) as nb_orders_2026
from {{ ref('mart_orders') }}
where order_date >= date('2026-01-01')
  and order_date < date('2027-01-01');

-- Exercise 2: Orders per month in 2026.
select
    date_trunc(order_date, month) as order_month,
    count(*) as nb_orders
from {{ ref('mart_orders') }}
where order_date >= date('2026-01-01')
  and order_date < date('2027-01-01')
group by 1
order by 1;

-- Exercise 3: Average qty_product per order, per month in 2026.
select
    date_trunc(order_date, month) as order_month,
    round(avg(qty_product), 2) as avg_qty_products_per_order
from {{ ref('mart_orders') }}
where order_date >= date('2026-01-01')
  and order_date < date('2027-01-01')
group by 1
order by 1;
