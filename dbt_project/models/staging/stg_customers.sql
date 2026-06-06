-- models/staging/stg_customers.sql
-- ─────────────────────────────────────────────────────────────
-- Cleans raw customer records. Standardises names, segments,
-- and adds tenure calculation.

with source as (

    select * from {{ source('shopflow_raw', 'raw_customers') }}

),

cleaned as (

    select
        customer_id,

        -- Clean name fields
        initcap(trim(first_name))                          as first_name,
        initcap(trim(last_name))                           as last_name,
        lower(trim(email))                                 as email,
        initcap(trim(city))                                as city,
        initcap(trim(state))                               as state,

        cast(signup_date as date)                          as signup_date,

        -- Standardise segment labels
        initcap(trim(customer_segment))                    as customer_segment,

        -- How many days has this customer been with us?
        date_diff(current_date(), cast(signup_date as date), day)
                                                           as customer_tenure_days,

        -- Bucket by tenure
        case
            when date_diff(current_date(), cast(signup_date as date), day) <= 30
                then 'New (0-30d)'
            when date_diff(current_date(), cast(signup_date as date), day) <= 180
                then 'Growing (1-6m)'
            when date_diff(current_date(), cast(signup_date as date), day) <= 365
                then 'Established (6-12m)'
            else 'Loyal (12m+)'
        end                                                as tenure_band

    from source
    where customer_id is not null

)

select * from cleaned
