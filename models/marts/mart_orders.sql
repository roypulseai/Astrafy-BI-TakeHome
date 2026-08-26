-- Grain: exactly one row per order.
-- This is the canonical order-level analytical mart.

{{ config(
    materialized='table',
    cluster_by=["customer_id", "order_segmentation"]
) }}

with order_history as (

    select *
    from {{ ref('int_order_customer_history') }}

),

product_summary as (

    select *
    from {{ ref('int_order_product_summary') }}

),

latest_customer_profile as (

    select
        customer_id,
        {{ get_order_segment('prior_orders_last_12_months') }} as customer_profile

    from order_history

    qualify row_number() over (
        partition by customer_id
        order by order_date desc, order_id desc
    ) = 1

)

select
    o.order_id,
    o.customer_id,
    o.order_date,

    extract(year from o.order_date) as order_year,
    extract(month from o.order_date) as order_month,
    date_trunc(o.order_date, month) as order_month_start,

    o.net_sales,

    coalesce(p.qty_product, 0) as qty_product,
    coalesce(p.product_line_count, 0) as product_line_count,
    coalesce(p.distinct_product_count, 0) as distinct_product_count,

    o.prior_orders_last_12_months,
    o.has_complete_12_month_history,

    {{ get_order_segment('o.prior_orders_last_12_months') }}
        as order_segmentation,

    -- Defensive fallback: latest_customer_profile is derived from the same
    -- order_history CTE, so every customer_id should match. The coalesce
    -- guards against edge cases if the CTE logic changes in the future.
    coalesce(lp.customer_profile, {{ get_order_segment('o.prior_orders_last_12_months') }})
        as customer_profile,

    1 as order_count

from order_history o

left join product_summary p
    on o.order_id = p.order_id

left join latest_customer_profile lp
    on o.customer_id = lp.customer_id
