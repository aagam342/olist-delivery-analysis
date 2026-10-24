
-- =====================================================================
-- 11_delivery_kpis.sql
-- Theme A: Delivery KPIs
--
-- Source : v_delivered_orders (one row per delivered order, see 10_base_views.sql)
-- Run    : psql -U postgres -d olist -f sql/11_delivery_kpis.sql -o outputs/11_delivery_kpis_results.txt
-- =====================================================================


-- ---------------------------------------------------------------------
-- A1. Overall delivery KPIs
-- Question  : What are the headline delivery numbers for the delivered scope?
-- Output    : one row: delivered_orders, late_orders, late_pct,
--             avg_delivery_days, median_delivery_days,
--             avg_delay_days_late_only, avg_days_early_vs_estimate
-- Notes     : delay_days is NULL for on-time orders, so AVG(delay_days)
--             averages late orders only. days_vs_estimate is delivery minus
--             estimate, so its negative is "days earlier than promised".
-- Validation: delivered_orders = 96470, late_orders = 6534, late_pct = 6.77
-- ---------------------------------------------------------------------
SELECT COUNT(*)                                                     AS delivered_orders,
       COUNT(*) FILTER (WHERE is_late)                              AS late_orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_late) / COUNT(*), 2) AS late_pct,
       ROUND(AVG(delivery_days), 1)                                 AS avg_delivery_days,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days))::numeric, 1) AS median_delivery_days,
       ROUND(AVG(delay_days), 1)                                    AS avg_delay_days_late_only,
       ROUND(AVG(-days_vs_estimate), 1)                             AS avg_days_early_vs_estimate
FROM v_delivered_orders;


-- ---------------------------------------------------------------------
-- A2. Delivery timing buckets
-- Question  : How are delivered orders spread across early, on the
--             estimated date, and late (by length of delay)?
-- Output    : one row per bucket in logical order: bucket, orders, pct_of_orders
-- Validation: orders add up to 96470; 'On estimated date' = 1292;
--             the four 'Late' buckets add up to 6534.
-- ---------------------------------------------------------------------
SELECT CASE
           WHEN days_vs_estimate < 0              THEN 'Early'
           WHEN days_vs_estimate = 0              THEN 'On estimated date'
           WHEN days_vs_estimate BETWEEN 1 AND 3  THEN 'Late 1-3 days'
           WHEN days_vs_estimate BETWEEN 4 AND 7  THEN 'Late 4-7 days'
           WHEN days_vs_estimate BETWEEN 8 AND 14 THEN 'Late 8-14 days'
           ELSE 'Late 15+ days'
       END AS bucket,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_orders
FROM v_delivered_orders
GROUP BY 1
ORDER BY MIN(days_vs_estimate);


-- ---------------------------------------------------------------------
-- A3. Revenue exposure
-- Question  : How much revenue sits on late orders, and what share of total?
-- Output    : one row: total_revenue, late_revenue, on_time_revenue, late_revenue_pct
-- Validation: late_revenue + on_time_revenue = total_revenue.
-- ---------------------------------------------------------------------
SELECT SUM(order_revenue)                                      AS total_revenue,
       SUM(order_revenue) FILTER (WHERE is_late)               AS late_revenue,
       SUM(order_revenue) FILTER (WHERE NOT is_late)           AS on_time_revenue,
       ROUND(100.0 * SUM(order_revenue) FILTER (WHERE is_late)
             / SUM(order_revenue), 2)                          AS late_revenue_pct
FROM v_delivered_orders;
