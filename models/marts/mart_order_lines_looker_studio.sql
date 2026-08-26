-- Thin BI view over mart_order_lines for Looker Studio product-level analysis.
-- Grain: one row per order × product (same as mart_order_lines).
-- Product-level aggregations are in mart_product_summary.

{{ config(
    materialized='view'
) }}

select
    product_id,
    order_date,
    order_year,
    order_month,
    order_month_start,
    order_segmentation,
    customer_profile,
    has_complete_12_month_history,

    quantity as units_sold,
    net_sales,
    revenue_per_unit,
    cast(1 as int64) as order_line_count  -- SUM gives total line count

from {{ ref('mart_order_lines') }}
