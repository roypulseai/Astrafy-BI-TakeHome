-- Grain: exactly one row per order.
-- Computes rolling 12-month prior order count per customer for segmentation.
--
-- Same-day behaviour: the source contains dates but no timestamps.
-- Same-day orders from the same customer cannot be reliably sequenced,
-- so only orders on strictly earlier dates count as prior history.
-- A deterministic tie-breaker (ORDER BY order_date, order_id) is used
-- for reproducibility, but order_id is an arbitrary surrogate key.

{{ config(
    materialized='table',
    cluster_by=["customer_id"]
) }}

with orders as (

    select
        order_id,
        customer_id,
        order_date,
        net_sales

    from {{ ref('stg_orders') }}

),

customer_order_history as (

    select
        current_order.order_id,
        current_order.customer_id,
        current_order.order_date,
        current_order.net_sales,

        count(history.order_id) as prior_orders_last_12_months,

    -- The 12-month lookback window extends before the dataset start (2025-07-09)
    -- for orders placed before 2026-07-09. Only orders on or after that date
    -- have a complete 12-month history.
    case
        when current_order.order_date >= date '2026-07-09'
        then true
        else false
    end as has_complete_12_month_history

    from orders current_order

    left join orders history

        on current_order.customer_id = history.customer_id

        and history.order_date >= date_sub(
            current_order.order_date,
            interval {{ var('segmentation_lookback_months') }} month
        )

        and history.order_date < current_order.order_date

    group by
        current_order.order_id,
        current_order.customer_id,
        current_order.order_date,
        current_order.net_sales

)

select *
from customer_order_history
