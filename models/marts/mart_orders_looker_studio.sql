-- Thin BI presentation view for Looker Studio.
-- Grain: exactly one row per order.
-- Excludes technical identifiers; adds pseudonymous customer_ref for
-- distinct-customer aggregation and order_count for order totals.

{{ config(materialized='view') }}

select
    order_date,
    order_year,
    order_month,
    order_month_start,
    net_sales,
    qty_product,
    product_line_count,
    distinct_product_count,
    order_segmentation,
    customer_profile,
    has_complete_12_month_history,
    order_count,
    to_hex(sha256(cast(customer_id as string))) as customer_ref
from {{ ref('mart_orders') }}
