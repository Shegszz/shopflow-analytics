-- models/marts/mart_daily_revenue.sql
-- ─────────────────────────────────────────────────────────────
-- Daily revenue summary table. Powers the main revenue trend
-- chart and KPI cards in the Power BI dashboard.
-- Includes 7-day rolling average and month-to-date totals.

with orders as (

    select * from {{ ref('stg_orders') }}
    where is_completed = true     -- Only count completed orders in revenue

),

items as (

    select * from {{ ref('stg_order_items') }}

),

daily_base as (

    select
        o.order_date,
        o.order_year,
        o.order_month,
        o.order_week,
        o.order_month_key,

        count(distinct o.order_id)          as total_orders,
        count(distinct o.customer_id)       as unique_customers,
        sum(i.line_total)                   as gross_revenue,
        sum(i.quantity)                     as total_units_sold,
        avg(o.order_total)                  as avg_order_value,
        countif(i.has_discount)             as discounted_items,
        sum(
            case when i.has_discount then i.unit_price * i.quantity * (i.discount_pct / 100)
                 else 0
            end
        )                                   as total_discount_given

    from orders o
    left join items i on o.order_id = i.order_id
    group by 1, 2, 3, 4, 5

),

with_rolling as (

    select
        *,

        -- 7-day rolling average revenue
        avg(gross_revenue) over (
            order by order_date
            rows between 6 preceding and current row
        )                                                   as revenue_7d_avg,

        -- Month-to-date cumulative revenue
        sum(gross_revenue) over (
            partition by order_month_key
            order by order_date
            rows between unbounded preceding and current row
        )                                                   as mtd_revenue,

        -- Day-over-day revenue change
        lag(gross_revenue) over (order by order_date)       as prev_day_revenue

    from daily_base

),

final as (

    select
        *,
        round(
            safe_divide(gross_revenue - prev_day_revenue, prev_day_revenue) * 100,
            1
        )                                                   as revenue_dod_pct_change

    from with_rolling

)

select * from final
order by order_date desc
