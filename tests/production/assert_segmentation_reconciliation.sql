-- Reconciliation test: verify that the dbt-computed order_segmentation
-- matches the LookML-derived rule using the same dbt vars as the macro.
-- This should return 0 rows if both implementations agree.

with lookml_segmentation as (
    select
        order_id,
        case
            when prior_orders_last_12_months <= {{ var('new_customer_max_prior_orders') }} then 'New'
            when prior_orders_last_12_months between {{ var('returning_min_prior_orders') }} and {{ var('returning_max_prior_orders') }} then 'Returning'
            when prior_orders_last_12_months >= {{ var('vip_min_prior_orders') }} then 'VIP'
            else 'Unknown'
        end as lookml_segment
    from {{ ref('mart_orders') }}
)

select
    l.order_id,
    l.lookml_segment,
    m.order_segmentation as warehouse_segment

from lookml_segmentation l

join {{ ref('mart_orders') }} m
    on l.order_id = m.order_id

where l.lookml_segment != m.order_segmentation
