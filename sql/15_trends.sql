
-- =====================================================================
-- 15_trends.sql
-- Theme E: Trends over time
--
-- Source : v_delivered_orders
-- Window : purchase months January 2017 to August 2018 (20 months), as
--          decided in docs/problem_statement.md. The months before and after
--          have very few orders and would distort trends and growth rates.
--          The filter is applied BEFORE the growth calculations, so the first
--          month has no previous month.
-- Run    : psql -U postgres -d olist -f sql/15_trends.sql -o outputs/15_trends_results.txt
-- =====================================================================


-- ---------------------------------------------------------------------
-- E1. Monthly summary
-- Question  : How do orders, revenue, late rate, and review score move
--             month by month?
-- Output    : purchase_month, orders, revenue, late_orders, late_pct, avg_review_score
-- Validation: exactly 20 rows; the orders column adds up to slightly less
--             than 96470 (the orders in the excluded sparse months).
-- ---------------------------------------------------------------------
SELECT purchase_month,
       COUNT(*)                                                     AS orders,
       SUM(order_revenue)                                           AS revenue,
       COUNT(*) FILTER (WHERE is_late)                              AS late_orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_late) / COUNT(*), 2) AS late_pct,
       ROUND(AVG(review_score), 2)                                  AS avg_review_score
FROM v_delivered_orders
WHERE purchase_month BETWEEN '2017-01-01' AND '2018-08-01'
GROUP BY purchase_month
ORDER BY purchase_month;


-- ---------------------------------------------------------------------
-- E2. Month-over-month growth
-- Question  : How fast do orders and revenue grow from one month to the next?
-- Output    : purchase_month, orders, prev_orders, orders_mom_pct,
--             revenue, prev_revenue, revenue_mom_pct
-- Validation: 20 rows; growth is NULL for January 2017 only, so 19 values.
-- ---------------------------------------------------------------------
WITH monthly AS (
    SELECT purchase_month,
           COUNT(*)           AS orders,
           SUM(order_revenue) AS revenue
    FROM v_delivered_orders
    WHERE purchase_month BETWEEN '2017-01-01' AND '2018-08-01'
    GROUP BY purchase_month
),
with_prev AS (
    SELECT purchase_month,
           orders,
           LAG(orders)  OVER w AS prev_orders,
           revenue,
           LAG(revenue) OVER w AS prev_revenue
    FROM monthly
    WINDOW w AS (ORDER BY purchase_month)
)
SELECT purchase_month,
       orders,
       prev_orders,
       ROUND(100.0 * (orders - prev_orders) / NULLIF(prev_orders, 0), 2)   AS orders_mom_pct,
       revenue,
       prev_revenue,
       ROUND(100.0 * (revenue - prev_revenue) / NULLIF(prev_revenue, 0), 2) AS revenue_mom_pct
FROM with_prev
ORDER BY purchase_month;


-- ---------------------------------------------------------------------
-- E3. Year-over-year growth
-- Question  : How do orders and revenue compare with the same month a
--             year earlier?
-- Output    : purchase_month, orders, orders_same_month_last_year, orders_yoy_pct,
--             revenue, revenue_same_month_last_year, revenue_yoy_pct
-- Notes     : the same month of the previous year is found by matching the
--             date (self-join), not by counting 12 rows back, so a missing
--             month cannot shift the comparison.
-- Validation: growth is available for January to August 2018 only (8 values);
--             months of 2017 show NULL.
-- ---------------------------------------------------------------------
WITH monthly AS (
    SELECT purchase_month,
           COUNT(*)           AS orders,
           SUM(order_revenue) AS revenue
    FROM v_delivered_orders
    WHERE purchase_month BETWEEN '2017-01-01' AND '2018-08-01'
    GROUP BY purchase_month
)
SELECT cur.purchase_month,
       cur.orders,
       prev.orders                                                          AS orders_same_month_last_year,
       ROUND(100.0 * (cur.orders - prev.orders) / NULLIF(prev.orders, 0), 2) AS orders_yoy_pct,
       cur.revenue,
       prev.revenue                                                         AS revenue_same_month_last_year,
       ROUND(100.0 * (cur.revenue - prev.revenue) / NULLIF(prev.revenue, 0), 2) AS revenue_yoy_pct
FROM monthly cur
LEFT JOIN monthly prev
       ON prev.purchase_month = (cur.purchase_month - INTERVAL '1 year')::date
ORDER BY cur.purchase_month;
