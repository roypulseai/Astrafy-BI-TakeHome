{{ config(severity='warn') }}

-- Every sales order should have a matching order header.
-- Known source defect: order_id 5361303 exists in stg_sales with no
-- matching row in stg_orders (customer 1382673). Expected 1 WARN row.
select s.order_id
from {{ ref('stg_sales') }} s
left join {{ ref('stg_orders') }} o
  using (order_id)
where o.order_id is null
