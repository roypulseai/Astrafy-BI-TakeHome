-- Grain: one row per order.
-- Source: orders_recrutement (raw).

{{ config(
    materialized='view'
) }}

with source as (

    select *
    from {{ source('raw', 'orders_recrutement') }}

),

cleaned as (

    select
        safe_cast(date_date as date) as order_date,
        cast(customers_id as int64) as customer_id,
        cast(orders_id as int64) as order_id,
        cast(net_sales as numeric) as net_sales

    from source

)

select *
from cleaned
