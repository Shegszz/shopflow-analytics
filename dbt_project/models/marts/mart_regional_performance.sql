-- models/marts/mart_regional_performance.sql
-- ─────────────────────────────────────────────────────────────
-- Revenue and order metrics broken down by US state.
-- Powers the regional map visual in the dashboard.

with orders as (

    select * from {{ ref('stg_orders') }}
    where is_completed = true

),

customers as (

    select customer_id, state, city
    from {{ ref('stg_customers') }}

),

items as (

    select * from {{ ref('stg_order_items') }}

),

joined as (

    select
        c.state,
        c.city,
        o.order_id,
        o.order_date,
        o.order_month_key,
        o.order_total,
        o.customer_id,
        i.line_total,
        i.quantity

    from orders o
    inner join customers c on o.customer_id = c.customer_id
    left  join items     i on o.order_id    = i.order_id

),

regional as (

    select
        state,
        order_month_key,

        count(distinct order_id)            as total_orders,
        count(distinct customer_id)         as unique_customers,
        round(sum(line_total), 2)           as gross_revenue,
        round(avg(order_total), 2)          as avg_order_value,
        sum(quantity)                       as units_sold,

        round(
            safe_divide(sum(line_total), count(distinct order_id)),
            2
        )                                   as revenue_per_order

    from joined
    group by 1, 2

)

select * from regional
order by order_month_key desc, gross_revenue desc
