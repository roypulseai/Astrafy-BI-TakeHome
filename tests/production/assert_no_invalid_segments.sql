select *
from {{ ref('mart_orders') }}
where order_segmentation not in (
    'New',
    'Returning',
    'VIP'
)
or order_segmentation is null
