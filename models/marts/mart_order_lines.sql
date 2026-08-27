-- Grain: exactly one row per order × product (order line).
-- Enriched with order-level attributes and segmentation for product analysis.
-- Product-level aggregations are in a separate model: mart_product_summary.

{{ config(
    materialized='table',
    cluster_by=["product_id", "customer_id"]
) }}

with sales as (

    select
        s.order_id,
        s.customer_id,
        s.product_id,
        s.order_date,
        s.qty,
        s.line_net_sales

    from {{ ref('stg_sales') }} s

    -- Exclude orphan sales (order_id 5361303) that have no matching order.
    -- This keeps mart_order_lines consistent with mart_orders.
    where exists (
        select 1 from {{ ref('stg_orders') }} o
        where o.order_id = s.order_id
    )

),

order_attrs as (

    select
        order_id,
        order_segmentation,
        customer_profile,
        has_complete_12_month_history

    from {{ ref('mart_orders') }}

)

select
    s.order_id,
    s.customer_id,
    s.product_id,
    s.order_date,

    extract(year from s.order_date) as order_year,
    extract(month from s.order_date) as order_month,
    date_trunc(s.order_date, month) as order_month_start,

    s.qty as quantity,
    s.line_net_sales as net_sales,

    -- Orphan sales (no matching order) were excluded upstream, so the join
    -- to mart_orders is guaranteed to match. No 'Unknown' fallback needed.
    oa.order_segmentation,
    oa.customer_profile,
    coalesce(oa.has_complete_12_month_history, false) as has_complete_12_month_history,

    round(safe_divide(s.line_net_sales, nullif(s.qty, 0)), 2) as revenue_per_unit

from sales s

left join order_attrs oa
    on s.order_id = oa.order_id
