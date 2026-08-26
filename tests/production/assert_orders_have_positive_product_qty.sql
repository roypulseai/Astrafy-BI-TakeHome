select *
from {{ ref('mart_orders') }}
where qty_product <= 0
   or qty_product is null
