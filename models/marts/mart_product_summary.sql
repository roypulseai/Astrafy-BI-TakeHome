-- Grain: one row per product.
-- Pre-aggregated product metrics for Looker Studio and reporting.
-- Source: mart_order_lines (which has one row per order × product).

{{ config(
    materialized='table',
    cluster_by=["product_id"]
) }}

with order_lines as (

    select
        product_id,
        order_id,
        customer_id,
        order_date,
        order_segmentation,
        quantity,
        net_sales

    from {{ ref('mart_order_lines') }}

),

product_metrics as (

    select
        product_id,

        sum(quantity) as total_units_sold,
        round(sum(net_sales), 2) as total_product_revenue,
        count(distinct order_id) as orders_containing_product,
        count(distinct customer_id) as customers_buying_product,
        round(safe_divide(sum(net_sales), nullif(sum(quantity), 0)), 2) as avg_revenue_per_unit,
        round(safe_divide(sum(net_sales), nullif(count(distinct order_id), 0)), 2) as avg_revenue_per_order,

        -- Revenue by segment
        round(sum(case when order_segmentation = 'New' then net_sales else 0 end), 2) as new_customer_revenue,
        round(sum(case when order_segmentation = 'Returning' then net_sales else 0 end), 2) as returning_customer_revenue,
        round(sum(case when order_segmentation = 'VIP' then net_sales else 0 end), 2) as vip_revenue,

        min(order_date) as first_order_date,
        max(order_date) as last_order_date

    from order_lines
    group by product_id

),

product_order_months as (

    select
        product_id,
        count(distinct date_trunc(order_date, month)) as active_months

    from order_lines
    group by product_id

)

select
    pm.*,
    pom.active_months,
    round(safe_divide(pm.total_product_revenue, nullif(pom.active_months, 0)), 2) as avg_monthly_revenue,
    round(safe_divide(pm.orders_containing_product, nullif(pom.active_months, 0)), 2) as avg_monthly_orders

from product_metrics pm

left join product_order_months pom
    on pm.product_id = pom.product_id
