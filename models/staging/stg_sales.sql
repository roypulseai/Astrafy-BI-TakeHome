-- Grain: one row per order and product (order line).
-- Source: sales_recrutement (raw).
-- net_sales is renamed to line_net_sales to disambiguate from order-level net_sales.

{{ config(
    materialized='view'
) }}

with source as (

    select *
    from {{ source('raw', 'sales_recrutement') }}

),

cleaned as (

    select
        safe_cast(date_date as date) as order_date,
        cast(customer_id as int64) as customer_id,
        cast(order_id as int64) as order_id,
        cast(products_id as int64) as product_id,
        cast(net_sales as numeric) as line_net_sales,
        cast(qty as int64) as qty

    from source

)

select *
from cleaned
