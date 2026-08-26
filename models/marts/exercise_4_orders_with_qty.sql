-- Exercise 4: 2025/2026 order-level table with qty_product.
-- Grain: one row per order.

{{ config(materialized='view') }}

select
    order_id,
    customer_id,
    order_date,
    net_sales,
    qty_product
from {{ ref('mart_orders') }}
where order_date >= date('2025-01-01')
  and order_date < date('2027-01-01')
