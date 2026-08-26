-- Exercise 6: 2026 order-level table with segmentation.
-- Grain: one row per order.

{{ config(materialized='view') }}

select
    order_id,
    customer_id,
    order_date,
    net_sales,
    qty_product,
    order_segmentation
from {{ ref('mart_orders') }}
where order_date >= date('2026-01-01')
  and order_date < date('2027-01-01')
