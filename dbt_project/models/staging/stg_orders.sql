-- models/staging/stg_orders.sql
-- ─────────────────────────────────────────────────────────────
-- Cleans and standardises raw orders from BigQuery ingestion.
-- Casts types, filters junk rows, adds derived columns.

with source as (

    select * from {{ source('shopflow_raw', 'raw_orders') }}

),

cleaned as (

    select
        order_id,
        customer_id,

        -- Safe date casting
        cast(order_date as date)                          as order_date,
        cast(order_timestamp as timestamp)                as order_timestamp,

        -- Normalise status to lowercase
        lower(trim(order_status))                         as order_status,

        payment_method,
        shipping_days,

        -- Guard against negative totals (data quality)
        case
            when order_total < 0 then 0
            else round(cast(order_total as numeric), 2)
        end                                               as order_total,

        -- Derived flags
        case
            when lower(order_status) = 'completed' then true
            else false
        end                                               as is_completed,

        case
            when lower(order_status) = 'returned' then true
            else false
        end                                               as is_returned,

        -- Date parts for easy aggregation downstream
        extract(year  from cast(order_date as date))      as order_year,
        extract(month from cast(order_date as date))      as order_month,
        extract(week  from cast(order_date as date))      as order_week,
        format_date('%Y-%m', cast(order_date as date))    as order_month_key

    from source
    where
        order_id     is not null
        and customer_id is not null
        and order_date  is not null

)

select * from cleaned
