-- =====================================================================
-- 10_base_views.sql
-- Olist Delivery Performance and Customer Satisfaction
--
-- Purpose : Build reusable views that implement the definitions in
--           docs/kpi_definitions.md and the decisions in
--           docs/problem_statement.md, so every analysis query starts
--           from the same, correct base.
-- Run     : psql -U postgres -d olist -f sql/10_base_views.sql
-- Note    : Safe to re-run (CREATE OR REPLACE).
--
-- Views (and their grain = what one row represents)
--   v_order_review     one row per order       latest review only
--   v_delivered_orders one row per order       delivered scope, with late flag,
--                                              delay days, revenue, review score
--   v_seller_orders    one row per seller x order   seller attribution rule
--   v_category_orders  one row per category x order same rule for categories
--
-- Why views?
--   * A definition (for example "late") is written once. If it ever
--     changes, it changes here, and every query follows.
--   * Queries become short and readable.
--   * The same views can feed Python and Power BI later.
--
-- Important: the seller and category views have MORE rows than orders,
-- because an order with several sellers (or categories) appears once
-- for each. Never use COUNT(*) on them to count orders overall. Use
-- v_delivered_orders for order-level totals.
-- =====================================================================


-- ---------------------------------------------------------------------
-- v_order_review: one review per order (the most recent).
-- DISTINCT ON keeps the first row for each order_id according to the
-- ORDER BY. The extra sort columns break ties so the result is always
-- the same. (DISTINCT ON is PostgreSQL-specific; in other databases the
-- same result comes from ROW_NUMBER() OVER (PARTITION BY order_id ...).)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_order_review AS
SELECT DISTINCT ON (order_id)
       order_id,
       review_score,
       review_creation_date
FROM order_reviews
ORDER BY order_id,
         review_creation_date DESC,
         review_answer_timestamp DESC NULLS LAST,
         review_id;


-- ---------------------------------------------------------------------
-- v_delivered_orders: the delivered scope, one row per order.
--   Scope    : status = 'delivered' AND delivery date is not null
--   is_late  : delivered on a later calendar DATE than the estimate
--   delay_days     : days late; NULL for orders that are not late, so
--                    AVG(delay_days) averages late orders only
--   days_vs_estimate : delivery date minus estimated date in days
--                    (negative = early, 0 = on the estimated date,
--                     positive = late)
--   order_revenue  : sum of item price (freight excluded)
--   review_score   : latest review; NULL when the order has no review
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_delivered_orders AS
SELECT o.order_id,
       c.customer_unique_id,
       c.customer_state,
       o.order_purchase_timestamp,
       DATE_TRUNC('month', o.order_purchase_timestamp)::date                           AS purchase_month,
       o.order_delivered_customer_date,
       o.order_estimated_delivery_date,
       (o.order_delivered_customer_date::date - o.order_purchase_timestamp::date)      AS delivery_days,
       (o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date) AS days_vs_estimate,
       (o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date) AS is_late,
       CASE WHEN o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date
            THEN o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date
       END                                                                             AS delay_days,
       i.order_revenue,
       i.n_items,
       r.review_score
FROM orders o
JOIN customers c        ON c.customer_id = o.customer_id
LEFT JOIN (
        SELECT order_id,
               SUM(price) AS order_revenue,
               COUNT(*)   AS n_items
        FROM order_items
        GROUP BY order_id
     ) i                ON i.order_id = o.order_id
LEFT JOIN v_order_review r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;


-- ---------------------------------------------------------------------
-- v_seller_orders: one row per seller and order.
-- Implements the seller attribution rule: an order counts toward every
-- seller who has an item in it. seller_revenue is only that seller's
-- part of the order.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_seller_orders AS
SELECT oi.seller_id,
       s.seller_state,
       d.order_id,
       d.customer_state,
       d.purchase_month,
       d.is_late,
       d.delay_days,
       d.review_score,
       SUM(oi.price) AS seller_revenue
FROM v_delivered_orders d
JOIN order_items oi ON oi.order_id = d.order_id
JOIN sellers s      ON s.seller_id = oi.seller_id
GROUP BY oi.seller_id, s.seller_state, d.order_id, d.customer_state,
         d.purchase_month, d.is_late, d.delay_days, d.review_score;


-- ---------------------------------------------------------------------
-- v_category_orders: one row per product category and order.
-- Same idea as v_seller_orders. Missing categories (610 products) and
-- categories without an English translation (2 categories) are both
-- labeled 'unknown', as decided in the problem statement.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_category_orders AS
SELECT COALESCE(t.product_category_name_english, 'unknown') AS category,
       d.order_id,
       d.customer_state,
       d.purchase_month,
       d.is_late,
       d.delay_days,
       d.review_score,
       SUM(oi.price) AS category_revenue
FROM v_delivered_orders d
JOIN order_items oi ON oi.order_id = d.order_id
JOIN products p     ON p.product_id = oi.product_id
LEFT JOIN product_category_name_translation t
       ON t.product_category_name = p.product_category_name
GROUP BY COALESCE(t.product_category_name_english, 'unknown'), d.order_id,
         d.customer_state, d.purchase_month, d.is_late, d.delay_days, d.review_score;


-- =====================================================================
-- VERIFICATION
-- Run these right after creating the views and compare with the
-- expected values. If a number differs, stop and find out why before
-- starting the analysis.
-- =====================================================================

-- V1. Scope: expected 96470 orders, 6534 late, 95824 with a review.
SELECT 'V1. v_delivered_orders' AS check_name,
       COUNT(*)                        AS orders,
       COUNT(*) FILTER (WHERE is_late) AS late_orders,
       COUNT(review_score)             AS orders_with_review
FROM v_delivered_orders;

-- V2. One review per order: expected 98673 (every reviewed order once).
SELECT 'V2. v_order_review' AS check_name,
       COUNT(*)                  AS rows,
       COUNT(DISTINCT order_id)  AS distinct_orders
FROM v_order_review;

-- V3. Fan-out views: row counts must be at least the order count plus
-- the multi-seller surplus. Expected for sellers: 97745 or more
-- (96470 orders + at least 1275 extra rows for multi-seller orders).
SELECT 'V3. fan-out views' AS check_name,
       (SELECT COUNT(*) FROM v_seller_orders)   AS seller_order_rows,
       (SELECT COUNT(*) FROM v_category_orders) AS category_order_rows;

-- V4. Revenue must be identical in all three views, because every item
-- belongs to exactly one order, one seller, and one category.
SELECT 'V4. revenue reconciliation' AS check_name,
       (SELECT SUM(order_revenue)    FROM v_delivered_orders) AS order_view_revenue,
       (SELECT SUM(seller_revenue)   FROM v_seller_orders)    AS seller_view_revenue,
       (SELECT SUM(category_revenue) FROM v_category_orders)  AS category_view_revenue;
