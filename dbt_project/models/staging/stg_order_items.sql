-- models/staging/stg_order_items.sql
-- ─────────────────────────────────────────────────────────────
-- Cleans raw order line items. Recalculates line totals
-- to guard against upstream rounding errors.

with source as (

    select * from {{ source('shopflow_raw', 'raw_order_items') }}

),

cleaned as (

    select
        order_item_id,
        order_id,
        product_id,

        cast(quantity    as int64)                            as quantity,
        round(cast(unit_price  as numeric), 2)                as unit_price,
        cast(discount_pct as numeric)                         as discount_pct,

        -- Recalculate line total from source components (don't trust stored value)
        round(
            cast(unit_price as numeric)
            * cast(quantity as int64)
            * (1 - cast(discount_pct as numeric) / 100),
            2
        )                                                     as line_total,

        -- Was a discount applied?
        case
            when cast(discount_pct as numeric) > 0 then true
            else false
        end                                                   as has_discount

    from source
    where
        order_item_id is not null
        and quantity      > 0
        and unit_price    > 0

)

select * from cleaned
