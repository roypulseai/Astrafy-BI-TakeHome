-- Grain: exactly one row per order.
-- Computes rolling 12-month prior order count per customer for segmentation.
--
-- Same-day behaviour: the source contains dates but no timestamps.
-- Orders from the same customer placed on the same date cannot be reliably
-- sequenced. Therefore, only orders on strictly earlier dates are counted
-- as prior history.

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

    -- The 12-month lookback window extends before the dataset start
    -- for orders placed within the first 12 months. Only orders placed
    -- on/after dataset_start + lookback have a complete 12-month history.
    case
        when current_order.order_date >= date_add(
            date '{{ var('dataset_start_date') }}',
            interval {{ var('segmentation_lookback_months') }} month
        )
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
