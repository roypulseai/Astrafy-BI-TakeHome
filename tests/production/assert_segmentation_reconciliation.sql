-- Reconciliation test: verify that the dbt-computed order_segmentation
-- matches the LookML-derived rule (New = 0, Returning = 1-3, VIP = 4+).
-- This should return 0 rows if both implementations agree.

with lookml_segmentation as (
    select
        order_id,
        case
            when prior_orders_last_12_months <= 0 then 'New'
            when prior_orders_last_12_months between 1 and 3 then 'Returning'
            when prior_orders_last_12_months >= 4 then 'VIP'
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
