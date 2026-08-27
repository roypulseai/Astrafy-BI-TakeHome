-- Grain test: mart_order_lines must contain exactly one row per order x product.
-- This should return 0 rows if the documented grain is maintained.

select
    order_id,
    product_id,
    count(*) as row_count
from {{ ref('mart_order_lines') }}
group by order_id, product_id
having count(*) > 1
