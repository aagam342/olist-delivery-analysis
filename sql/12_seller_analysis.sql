
-- =====================================================================
-- 12_seller_analysis.sql
-- Theme B: Seller analysis
--
-- Source : v_seller_orders (one row per seller AND order). COUNT(*) per
--          seller is that seller's number of delivered orders. Do not use
--          COUNT(*) on this view to count orders overall.
-- Rule   : sellers are ranked only if they have at least 50 delivered
--          orders (decision recorded in docs/problem_statement.md).
-- Run    : psql -U postgres -d olist -f sql/12_seller_analysis.sql -o outputs/12_seller_analysis_results.txt
-- =====================================================================


-- ---------------------------------------------------------------------
-- B1. Sellers with the highest late rate
-- Question  : Which qualifying sellers have the highest late delivery rate?
-- Output    : seller_id, seller_state, seller_orders, late_orders, late_pct
--             Top 10 by late_pct (ties: more late orders first, then seller_id)
-- Validation: without LIMIT, exactly 425 sellers.
-- ---------------------------------------------------------------------
SELECT seller_id,
       seller_state,
       COUNT(*)                                                     AS seller_orders,
       COUNT(*) FILTER (WHERE is_late)                              AS late_orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_late) / COUNT(*), 2) AS late_pct
FROM v_seller_orders
GROUP BY seller_id, seller_state
HAVING COUNT(*) >= 50
ORDER BY late_pct DESC, late_orders DESC, seller_id
LIMIT 10;


-- ---------------------------------------------------------------------
-- B2. Seller ranking with a window function
-- Question  : What is each qualifying seller's rank by late rate?
-- Output    : seller_rank, seller_id, seller_orders, late_orders, late_pct
--             for all qualifying sellers
-- Validation: 425 rows; rank 1 is the same seller as the first row of B1.
-- ---------------------------------------------------------------------
WITH seller_stats AS (
    SELECT seller_id,
           seller_state,
           COUNT(*)                                                     AS seller_orders,
           COUNT(*) FILTER (WHERE is_late)                              AS late_orders,
           ROUND(100.0 * COUNT(*) FILTER (WHERE is_late) / COUNT(*), 2) AS late_pct
    FROM v_seller_orders
    GROUP BY seller_id, seller_state
    HAVING COUNT(*) >= 50
)
SELECT RANK() OVER (ORDER BY late_pct DESC, late_orders DESC) AS seller_rank,
       seller_id,
       seller_orders,
       late_orders,
       late_pct
FROM seller_stats
ORDER BY seller_rank, seller_id;


-- ---------------------------------------------------------------------
-- B3. Concentration of late orders (Pareto)
-- Question  : How concentrated are late orders? How many sellers, and what
--             percentage of all sellers, account for 50% and for 80% of
--             late orders?
-- Source    : all sellers with at least one delivered order, with no minimum
--             order filter, because concentration is about all late orders.
-- Notes     : the total of seller late orders is slightly higher than the
--             number of late orders, because a late order with several sellers
--             is counted once for each of its sellers. That total is used as
--             the denominator so the curve ends at exactly 100%.
-- Validation: the last row of part 1 has cumulative_share_pct = 100.00.
-- ---------------------------------------------------------------------

-- (1) Per-seller cumulative table
WITH seller_late AS (
    SELECT seller_id,
           COUNT(*) FILTER (WHERE is_late) AS late_orders
    FROM v_seller_orders
    GROUP BY seller_id
),
running AS (
    SELECT seller_id,
           late_orders,
           SUM(late_orders) OVER (ORDER BY late_orders DESC, seller_id)       AS cumulative_late_orders,
           SUM(late_orders) OVER ()                                           AS total_late_orders,
           ROW_NUMBER()     OVER (ORDER BY late_orders DESC, seller_id)       AS seller_position
    FROM seller_late
)
SELECT seller_id,
       late_orders,
       cumulative_late_orders,
       ROUND(100.0 * cumulative_late_orders / total_late_orders, 2) AS cumulative_share_pct,
       seller_position
FROM running
ORDER BY seller_position;

-- (2) How many sellers account for 50% and 80% of late orders
WITH seller_late AS (
    SELECT seller_id,
           COUNT(*) FILTER (WHERE is_late) AS late_orders
    FROM v_seller_orders
    GROUP BY seller_id
),
running AS (
    SELECT late_orders,
           SUM(late_orders) OVER (ORDER BY late_orders DESC, seller_id)       AS cumulative_late_orders,
           SUM(late_orders) OVER ()                                           AS total_late_orders,
           ROW_NUMBER()     OVER (ORDER BY late_orders DESC, seller_id)       AS seller_position,
           COUNT(*)         OVER ()                                           AS total_sellers
    FROM seller_late
)
SELECT MIN(seller_position) FILTER (WHERE cumulative_late_orders >= 0.5 * total_late_orders) AS sellers_for_50pct,
       ROUND(100.0 * MIN(seller_position) FILTER (WHERE cumulative_late_orders >= 0.5 * total_late_orders)
             / MAX(total_sellers), 2)                                                        AS pct_of_sellers_for_50,
       MIN(seller_position) FILTER (WHERE cumulative_late_orders >= 0.8 * total_late_orders) AS sellers_for_80pct,
       ROUND(100.0 * MIN(seller_position) FILTER (WHERE cumulative_late_orders >= 0.8 * total_late_orders)
             / MAX(total_sellers), 2)                                                        AS pct_of_sellers_for_80
FROM running;


-- ---------------------------------------------------------------------
-- B4. Coverage of the 50-order threshold, and stability of the top 10
-- Question  : (a) What share of delivered orders and of late orders involve
--                 at least one qualifying seller (at least 50 orders)?
--             (b) Does the top 10 list of worst sellers change if the
--                 minimum is 30 or 100 orders instead of 50?
-- Output    : (a) one row: pct_of_delivered_orders_covered, pct_of_late_orders_covered
--             (b) one row: number of sellers that appear in the top 10 at all
--                 three thresholds (30, 50, 100). 10 means the list is stable.
-- Validation: percentages are between 0 and 100.
-- ---------------------------------------------------------------------

-- (a) Coverage
WITH qualifying AS (
    SELECT seller_id
    FROM v_seller_orders
    GROUP BY seller_id
    HAVING COUNT(*) >= 50
)
SELECT ROUND(100.0 * COUNT(DISTINCT so.order_id)
             / (SELECT COUNT(*) FROM v_delivered_orders), 2) AS pct_of_delivered_orders_covered,
       ROUND(100.0 * COUNT(DISTINCT so.order_id) FILTER (WHERE so.is_late)
             / (SELECT COUNT(*) FROM v_delivered_orders WHERE is_late), 2) AS pct_of_late_orders_covered
FROM v_seller_orders so
JOIN qualifying q ON q.seller_id = so.seller_id;

-- (b) Stability of the top 10
WITH seller_stats AS (
    SELECT seller_id,
           COUNT(*)                                                     AS seller_orders,
           COUNT(*) FILTER (WHERE is_late)                              AS late_orders,
           ROUND(100.0 * COUNT(*) FILTER (WHERE is_late) / COUNT(*), 2) AS late_pct
    FROM v_seller_orders
    GROUP BY seller_id
),
top30 AS (
    SELECT seller_id FROM seller_stats
    WHERE seller_orders >= 30
    ORDER BY late_pct DESC, late_orders DESC, seller_id
    LIMIT 10
),
top50 AS (
    SELECT seller_id FROM seller_stats
    WHERE seller_orders >= 50
    ORDER BY late_pct DESC, late_orders DESC, seller_id
    LIMIT 10
),
top100 AS (
    SELECT seller_id FROM seller_stats
    WHERE seller_orders >= 100
    ORDER BY late_pct DESC, late_orders DESC, seller_id
    LIMIT 10
)
SELECT COUNT(*) AS sellers_in_all_three_top10
FROM (
    SELECT seller_id FROM top30
    INTERSECT
    SELECT seller_id FROM top50
    INTERSECT
    SELECT seller_id FROM top100
) AS common;
