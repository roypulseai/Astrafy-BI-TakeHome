-- Grain: exactly one row per order.
-- Aggregates product-line quantities from stg_sales to order grain.

{{ config(
    materialized='table'
) }}

select
    s.order_id,

    sum(s.qty) as qty_product,

    count(*) as product_line_count,

    count(distinct s.product_id) as distinct_product_count

from {{ ref('stg_sales') }} s

where exists (
    select 1 from {{ ref('stg_orders') }} o
    where o.order_id = s.order_id
)

group by s.order_id
