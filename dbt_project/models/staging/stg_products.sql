-- models/staging/stg_products.sql
-- ─────────────────────────────────────────────────────────────
-- Cleans raw product catalogue. Calculates margin metrics.

with source as (

    select * from {{ source('shopflow_raw', 'raw_products') }}

),

cleaned as (

    select
        product_id,
        trim(product_name)                                   as product_name,
        trim(category)                                       as category,
        trim(subcategory)                                    as subcategory,

        round(cast(cost_price    as numeric), 2)             as cost_price,
        round(cast(selling_price as numeric), 2)             as selling_price,
        stock_quantity,

        -- Derived margin metrics
        round(cast(selling_price as numeric) - cast(cost_price as numeric), 2)
                                                             as gross_profit_per_unit,

        round(
            safe_divide(
                cast(selling_price as numeric) - cast(cost_price as numeric),
                cast(selling_price as numeric)
            ) * 100,
            1
        )                                                    as gross_margin_pct

    from source
    where
        product_id    is not null
        and selling_price > 0

)

select * from cleaned
