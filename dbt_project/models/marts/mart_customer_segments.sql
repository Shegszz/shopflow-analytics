-- models/marts/mart_customer_segments.sql
-- ─────────────────────────────────────────────────────────────
-- RFM (Recency, Frequency, Monetary) customer segmentation.
-- Classic e-commerce analytics model.
-- Powers customer insights page in dashboard.
--
-- RFM Logic:
--   Recency  = days since last order (lower = better)
--   Frequency = total number of completed orders
--   Monetary  = total spend

with orders as (

    select * from {{ ref('stg_orders') }}
    where is_completed = true

),

customers as (

    select * from {{ ref('stg_customers') }}

),

customer_orders as (

    select
        customer_id,
        count(order_id)                                         as frequency,
        sum(order_total)                                        as monetary,
        max(order_date)                                         as last_order_date,
        min(order_date)                                         as first_order_date,
        date_diff(current_date(), max(order_date), day)         as recency_days,
        avg(order_total)                                        as avg_order_value

    from orders
    group by 1

),

rfm_scored as (

    select
        c.customer_id,
        c.first_name,
        c.last_name,
        c.state,
        c.customer_segment,
        c.signup_date,
        c.tenure_band,

        coalesce(o.frequency, 0)                                as order_count,
        coalesce(round(o.monetary, 2), 0)                       as total_spent,
        coalesce(round(o.avg_order_value, 2), 0)                as avg_order_value,
        o.last_order_date,
        o.first_order_date,
        coalesce(o.recency_days, 9999)                          as recency_days,

        -- RFM quintile scores (5 = best, 1 = worst)
        ntile(5) over (order by coalesce(o.recency_days, 9999) desc)
                                                                as recency_score,
        ntile(5) over (order by coalesce(o.frequency, 0))       as frequency_score,
        ntile(5) over (order by coalesce(o.monetary, 0))        as monetary_score

    from customers c
    left join customer_orders o on c.customer_id = o.customer_id

),

segmented as (

    select
        *,
        recency_score + frequency_score + monetary_score        as rfm_total,

        -- Human-readable RFM segment labels
        case
            when recency_score >= 4 and frequency_score >= 4 and monetary_score >= 4
                then 'Champions'
            when recency_score >= 3 and frequency_score >= 3
                then 'Loyal Customers'
            when recency_score >= 4 and frequency_score <= 2
                then 'Recent Customers'
            when recency_score >= 3 and frequency_score >= 2 and monetary_score >= 3
                then 'Potential Loyalists'
            when recency_score <= 2 and frequency_score >= 3 and monetary_score >= 3
                then 'At Risk'
            when recency_score <= 2 and frequency_score >= 4 and monetary_score >= 4
                then 'Cant Lose Them'
            when recency_score <= 2 and frequency_score <= 2
                then 'Lost'
            else 'Needs Attention'
        end                                                     as rfm_segment

    from rfm_scored

)

select * from segmented
order by total_spent desc
