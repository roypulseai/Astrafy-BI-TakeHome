with order_sales as (

    select
        order_id,
        net_sales
    from {{ ref('stg_orders') }}

),

line_sales as (

    select
        order_id,
        sum(line_net_sales) as line_net_sales
    from {{ ref('stg_sales') }}
    group by order_id

)

select
    o.order_id,
    o.net_sales,
    l.line_net_sales

from order_sales o

join line_sales l
    using (order_id)

where abs(o.net_sales - l.line_net_sales) > 0.01
