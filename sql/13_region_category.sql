
-- =====================================================================
-- 13_region_category.sql
-- Theme C: Region and category analysis
--
-- Sources:
--   v_delivered_orders  one row per order (state analysis)
--   v_category_orders   one row per category and order (an order with items
--                       in two categories counts once in each)
--   v_seller_orders     one row per seller and order
-- Volume rules (to avoid noisy rates on very small groups):
--   states             shown for all states, flagged when below 100 orders
--   categories         shown only with at least 100 orders
--   state x category   shown only with at least 50 orders
-- Run    : psql -U postgres -d olist -f sql/13_region_category.sql -o outputs/13_region_category_results.txt
-- =====================================================================


-- ---------------------------------------------------------------------
-- C1. Late rate by customer state
-- Question  : Which customer states have the highest late rate?
-- Output    : customer_state, orders, late_orders, late_pct,
--             pct_of_all_orders, low_volume (true when orders < 100)
-- Validation: orders add up to 96470; pct_of_all_orders adds up to 100;
--             at most 27 states.
-- ---------------------------------------------------------------------
SELECT customer_state,
       COUNT(*)                                                     AS orders,
       COUNT(*) FILTER (WHERE is_late)                              AS late_orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_late) / COUNT(*), 2) AS late_pct,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)           AS pct_of_all_orders,
       COUNT(*) < 100                                               AS low_volume
FROM v_delivered_orders
GROUP BY customer_state
ORDER BY late_pct DESC, orders DESC;


-- ---------------------------------------------------------------------
-- C2. Late rate by product category
-- Question  : Which categories have the highest late rate?
-- Output    : category, orders, late_orders, late_pct
--             categories with at least 100 orders
-- Notes     : an order with items in two categories is counted in both.
-- Validation: without HAVING, at most 72 rows (71 translated categories plus
--             'unknown'); the orders column adds up to at least 96470.
-- ---------------------------------------------------------------------
SELECT category,
       COUNT(*)                                                     AS orders,
       COUNT(*) FILTER (WHERE is_late)                              AS late_orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_late) / COUNT(*), 2) AS late_pct
FROM v_category_orders
GROUP BY category
HAVING COUNT(*) >= 100
ORDER BY late_pct DESC, orders DESC;


-- ---------------------------------------------------------------------
-- C3. Worst state and category combinations
-- Question  : Which state and category combinations have the highest late
--             rate, among combinations with enough orders?
-- Output    : customer_state, category, orders, late_orders, late_pct
--             at least 50 orders, top 15 by late_pct
-- Validation: every row shows orders >= 50.
-- ---------------------------------------------------------------------
SELECT customer_state,
       category,
       COUNT(*)                                                     AS orders,
       COUNT(*) FILTER (WHERE is_late)                              AS late_orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_late) / COUNT(*), 2) AS late_pct
FROM v_category_orders
GROUP BY customer_state, category
HAVING COUNT(*) >= 50
ORDER BY late_pct DESC, orders DESC, customer_state, category
LIMIT 15;


-- ---------------------------------------------------------------------
-- C4. Same-state versus cross-state shipping
-- Question  : Are orders shipped within the same state delivered late less
--             often than orders shipped across states?
-- Output    : shipping_type, seller_order_rows, late_orders, late_pct
-- Notes     : each row of v_seller_orders is one seller and one order, so an
--             order with two sellers appears twice.
-- Validation: the two groups add up to the total number of rows in
--             v_seller_orders (the figure from verification V3).
-- ---------------------------------------------------------------------
SELECT CASE WHEN seller_state = customer_state THEN 'Same state'
            ELSE 'Cross-state'
       END                                                          AS shipping_type,
       COUNT(*)                                                     AS seller_order_rows,
       COUNT(*) FILTER (WHERE is_late)                              AS late_orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_late) / COUNT(*), 2) AS late_pct
FROM v_seller_orders
GROUP BY 1
ORDER BY late_pct DESC;
