-- Challenge regression test: fail if 2026 segmented order count differs from stg_orders.
-- Validates that segmentation does not create or lose orders.

with segmented_count as (
    select count(*) as cnt
    from {{ ref('exercise_6_orders_segmented') }}
),

source_count as (
    select count(*) as cnt
    from {{ ref('stg_orders') }}
    where extract(year from order_date) = 2026
)

select *
from segmented_count
cross join source_count
where segmented_count.cnt != source_count.cnt
