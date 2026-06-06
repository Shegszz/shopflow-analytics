-- models/marts/mart_product_performance.sql
-- ─────────────────────────────────────────────────────────────
-- Product and category performance table.
-- Answers: which categories drive revenue? which have best margins?
-- Powers the product performance page of the dashboard.

with items as (

    select * from {{ ref('stg_order_items') }}

),

orders as (

    select order_id, order_date, order_month_key, is_completed
    from {{ ref('stg_orders') }}
    where is_completed = true

),

products as (

    select * from {{ ref('stg_products') }}

),

joined as (

    select
        p.product_id,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost_price,
        p.selling_price,
        p.gross_margin_pct,
        o.order_date,
        o.order_month_key,
        i.quantity,
        i.line_total,
        i.has_discount,
        i.discount_pct,

        -- Calculate actual cost for this line
        p.cost_price * i.quantity                           as line_cost,

        -- Actual gross profit on this line
        i.line_total - (p.cost_price * i.quantity)          as line_gross_profit

    from items i
    inner join orders  o on i.order_id  = o.order_id
    inner join products p on i.product_id = p.product_id

),

category_monthly as (

    select
        order_month_key,
        category,
        subcategory,

        count(distinct product_id)                          as products_sold,
        sum(quantity)                                       as units_sold,
        round(sum(line_total), 2)                           as gross_revenue,
        round(sum(line_cost), 2)                            as total_cost,
        round(sum(line_gross_profit), 2)                    as gross_profit,

        round(
            safe_divide(sum(line_gross_profit), sum(line_total)) * 100,
            1
        )                                                   as realised_margin_pct,

        round(avg(line_total / nullif(quantity, 0)), 2)     as avg_selling_price,
        countif(has_discount)                               as discounted_lines,
        round(avg(case when has_discount then discount_pct end), 1)
                                                            as avg_discount_pct

    from joined
    group by 1, 2, 3

)

select * from category_monthly
order by order_month_key desc, gross_revenue desc
