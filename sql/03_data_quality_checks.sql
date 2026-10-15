-- =====================================================================
-- 03_data_quality_checks.sql
-- Olist Delivery Performance and Customer Satisfaction
--
-- Purpose : Verify the loaded data before any analysis, and test the
--           assumptions written in docs/problem_statement.md.
-- Run     : psql -U postgres -d olist -f sql/03_data_quality_checks.sql -o outputs/dq_results.txt
--           (psql shows every result set; pgAdmin shows only the last
--            one when a script has many queries, so run one query at a
--            time there by selecting it and pressing F5.)
--
-- Sections
--   A  Row counts
--   B  Key uniqueness and duplicates
--   C  Missing values and order status
--   D  Referential integrity (orphan records)
--   E  Date range and date logic
--   F  Scope waterfall (how many orders survive each filter)
--   G  Seller structure (multi-seller orders, orders per seller)
--   H  Reviews
--   I  Delivery time outliers
--   J  Impact of the "late" definition (date vs timestamp)
-- =====================================================================


-- ---------------------------------------------------------------------
-- A. ROW COUNTS
-- Compare with the CSV row counts (pandas count in the setup guide).
-- ---------------------------------------------------------------------
SELECT 'A. row counts' AS section, table_name, row_count
FROM (
    SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
    UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
    UNION ALL SELECT 'product_category_name_translation', COUNT(*) FROM product_category_name_translation
    UNION ALL SELECT 'products', COUNT(*) FROM products
    UNION ALL SELECT 'geolocation', COUNT(*) FROM geolocation
    UNION ALL SELECT 'orders', COUNT(*) FROM orders
    UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
    UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
    UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
) t;


-- ---------------------------------------------------------------------
-- B. KEY UNIQUENESS AND DUPLICATES
-- Primary keys already guarantee uniqueness for most tables.
-- The open questions are about reviews and customer identity.
-- ---------------------------------------------------------------------
SELECT 'B. duplicates' AS section, check_name, value
FROM (
    SELECT 'review_ids that appear more than once' AS check_name,
           COUNT(*) AS value
    FROM (SELECT review_id FROM order_reviews GROUP BY review_id HAVING COUNT(*) > 1) d

    UNION ALL
    SELECT 'orders that have more than one review',
           COUNT(*)
    FROM (SELECT order_id FROM order_reviews GROUP BY order_id HAVING COUNT(*) > 1) d

    UNION ALL
    SELECT 'distinct customer_id in customers', COUNT(DISTINCT customer_id) FROM customers

    UNION ALL
    SELECT 'distinct customer_unique_id in customers', COUNT(DISTINCT customer_unique_id) FROM customers
) t;


-- ---------------------------------------------------------------------
-- C. MISSING VALUES AND ORDER STATUS
-- One row per status: how many orders, and how many have a missing date.
-- Key question: do delivered orders have a delivery date?
-- ---------------------------------------------------------------------
SELECT 'C. orders by status' AS section,
       order_status,
       COUNT(*) AS orders,
       COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL)       AS null_purchase,
       COUNT(*) FILTER (WHERE order_approved_at IS NULL)              AS null_approved,
       COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL)   AS null_carrier_date,
       COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL)  AS null_delivery_date,
       COUNT(*) FILTER (WHERE order_estimated_delivery_date IS NULL)  AS null_estimated_date
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- Products and category translation
SELECT 'C. products and categories' AS section, check_name, value
FROM (
    SELECT 'products with missing category' AS check_name, COUNT(*) AS value
    FROM products WHERE product_category_name IS NULL

    UNION ALL
    SELECT 'distinct categories without an English translation',
           COUNT(DISTINCT p.product_category_name)
    FROM products p
    LEFT JOIN product_category_name_translation t
           ON t.product_category_name = p.product_category_name
    WHERE p.product_category_name IS NOT NULL
      AND t.product_category_name IS NULL
) t;

-- Which categories are missing a translation? (empty result means none)
SELECT 'C. categories missing translation' AS section,
       p.product_category_name,
       COUNT(*) AS products
FROM products p
LEFT JOIN product_category_name_translation t
       ON t.product_category_name = p.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL
GROUP BY p.product_category_name
ORDER BY products DESC;


-- ---------------------------------------------------------------------
-- D. REFERENTIAL INTEGRITY (ORPHAN RECORDS)
-- Each value should be 0 for a foreign key to be safe to add.
-- The last three checks are informational, not errors.
-- ---------------------------------------------------------------------
SELECT 'D. orphans' AS section, check_name, value
FROM (
    SELECT 'orders without a matching customer' AS check_name, COUNT(*) AS value
    FROM orders o
    WHERE NOT EXISTS (SELECT 1 FROM customers c WHERE c.customer_id = o.customer_id)

    UNION ALL
    SELECT 'order_items without a matching order', COUNT(*)
    FROM order_items oi
    WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.order_id = oi.order_id)

    UNION ALL
    SELECT 'order_items without a matching product', COUNT(*)
    FROM order_items oi
    WHERE NOT EXISTS (SELECT 1 FROM products p WHERE p.product_id = oi.product_id)

    UNION ALL
    SELECT 'order_items without a matching seller', COUNT(*)
    FROM order_items oi
    WHERE NOT EXISTS (SELECT 1 FROM sellers s WHERE s.seller_id = oi.seller_id)

    UNION ALL
    SELECT 'order_payments without a matching order', COUNT(*)
    FROM order_payments op
    WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.order_id = op.order_id)

    UNION ALL
    SELECT 'order_reviews without a matching order', COUNT(*)
    FROM order_reviews r
    WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.order_id = r.order_id)

    -- Informational
    UNION ALL
    SELECT 'INFO: orders with no items', COUNT(*)
    FROM orders o
    WHERE NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.order_id)

    UNION ALL
    SELECT 'INFO: orders with no payment', COUNT(*)
    FROM orders o
    WHERE NOT EXISTS (SELECT 1 FROM order_payments op WHERE op.order_id = o.order_id)

    UNION ALL
    SELECT 'INFO: orders with no review', COUNT(*)
    FROM orders o
    WHERE NOT EXISTS (SELECT 1 FROM order_reviews r WHERE r.order_id = o.order_id)
) t;


-- ---------------------------------------------------------------------
-- E. DATE RANGE AND DATE LOGIC
-- ---------------------------------------------------------------------

-- E1. Overall date range
SELECT 'E1. date range' AS section,
       MIN(order_purchase_timestamp)       AS first_purchase,
       MAX(order_purchase_timestamp)       AS last_purchase,
       MIN(order_delivered_customer_date)  AS first_delivery,
       MAX(order_delivered_customer_date)  AS last_delivery,
       MAX(order_estimated_delivery_date)  AS last_estimated_delivery
FROM orders;

-- E2. Orders per purchase month (look for sparse first and last months)
SELECT 'E2. orders per month' AS section,
       DATE_TRUNC('month', order_purchase_timestamp)::date AS purchase_month,
       COUNT(*) AS orders
FROM orders
GROUP BY 2
ORDER BY 2;

-- E3. Impossible or suspicious date combinations (each should be 0 or tiny)
SELECT 'E3. date logic' AS section, check_name, value
FROM (
    SELECT 'delivered to customer BEFORE purchase' AS check_name, COUNT(*) AS value
    FROM orders
    WHERE order_delivered_customer_date < order_purchase_timestamp

    UNION ALL
    SELECT 'delivered to customer BEFORE handed to carrier', COUNT(*)
    FROM orders
    WHERE order_delivered_customer_date < order_delivered_carrier_date

    UNION ALL
    SELECT 'estimated delivery BEFORE purchase', COUNT(*)
    FROM orders
    WHERE order_estimated_delivery_date < order_purchase_timestamp
) t;

-- E4. Does the estimated delivery date carry a time of day?
-- If with_time_component is 0, the estimate is date-only, which is why
-- the project compares dates and not raw timestamps.
SELECT 'E4. estimated date format' AS section,
       COUNT(*) AS orders,
       COUNT(*) FILTER (WHERE order_estimated_delivery_date::time <> TIME '00:00:00') AS with_time_component,
       COUNT(*) FILTER (WHERE order_delivered_customer_date::time <> TIME '00:00:00') AS delivery_with_time_component
FROM orders
WHERE order_estimated_delivery_date IS NOT NULL;


-- ---------------------------------------------------------------------
-- F. SCOPE WATERFALL
-- How many orders remain after each filter. Document these numbers.
-- ---------------------------------------------------------------------
SELECT 'F. scope waterfall' AS section, step, orders
FROM (
    SELECT '1. all orders' AS step, COUNT(*) AS orders FROM orders

    UNION ALL
    SELECT '2. status = delivered', COUNT(*)
    FROM orders
    WHERE order_status = 'delivered'

    UNION ALL
    SELECT '3. delivered and delivery date present', COUNT(*)
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL

    UNION ALL
    SELECT '4. ...and has at least one review', COUNT(*)
    FROM orders o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND EXISTS (SELECT 1 FROM order_reviews r WHERE r.order_id = o.order_id)
) t
ORDER BY step;


-- ---------------------------------------------------------------------
-- G. SELLER STRUCTURE
-- Settles the "seller attribution" and "minimum orders" decisions.
-- ---------------------------------------------------------------------

-- G1. How many delivered orders involve more than one seller?
SELECT 'G1. multi-seller orders' AS section,
       COUNT(*) AS delivered_orders,
       COUNT(*) FILTER (WHERE n_sellers > 1) AS multi_seller_orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE n_sellers > 1) / COUNT(*), 2) AS pct_multi_seller,
       COUNT(*) FILTER (WHERE n_items > 1)   AS multi_item_orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE n_items > 1) / COUNT(*), 2) AS pct_multi_item
FROM (
    SELECT o.order_id,
           COUNT(DISTINCT oi.seller_id) AS n_sellers,
           COUNT(*)                     AS n_items
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY o.order_id
) t;

-- G2. Distribution of delivered orders per seller, and how many sellers
-- would remain under different minimum-order thresholds.
SELECT 'G2. orders per seller' AS section,
       COUNT(*)                                         AS sellers,
       MIN(n_orders)                                    AS min_orders,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY n_orders))::numeric, 1) AS median_orders,
       MAX(n_orders)                                    AS max_orders,
       COUNT(*) FILTER (WHERE n_orders >= 10)           AS sellers_10_plus,
       COUNT(*) FILTER (WHERE n_orders >= 30)           AS sellers_30_plus,
       COUNT(*) FILTER (WHERE n_orders >= 50)           AS sellers_50_plus,
       COUNT(*) FILTER (WHERE n_orders >= 100)          AS sellers_100_plus
FROM (
    SELECT oi.seller_id, COUNT(DISTINCT o.order_id) AS n_orders
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY oi.seller_id
) t;


-- ---------------------------------------------------------------------
-- H. REVIEWS
-- ---------------------------------------------------------------------

-- H1. Score distribution (valid scores are 1 to 5)
SELECT 'H1. review score distribution' AS section,
       review_score,
       COUNT(*) AS reviews
FROM order_reviews
GROUP BY review_score
ORDER BY review_score;

-- H2. How many reviews does each reviewed order have?
SELECT 'H2. reviews per order' AS section,
       reviews_per_order,
       COUNT(*) AS orders
FROM (
    SELECT order_id, COUNT(*) AS reviews_per_order
    FROM order_reviews
    GROUP BY order_id
) t
GROUP BY reviews_per_order
ORDER BY reviews_per_order;


-- ---------------------------------------------------------------------
-- I. DELIVERY TIME OUTLIERS (delivered scope)
-- Days from purchase to delivery. Look at the tail, not only the median.
-- ---------------------------------------------------------------------
SELECT 'I. delivery days' AS section,
       COUNT(*)                                                                          AS orders,
       MIN(days)                                                                         AS min_days,
       ROUND((PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY days))::numeric, 1)           AS median_days,
       ROUND((PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY days))::numeric, 1)           AS p95_days,
       ROUND((PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY days))::numeric, 1)           AS p99_days,
       MAX(days)                                                                         AS max_days
FROM (
    SELECT order_delivered_customer_date::date - order_purchase_timestamp::date AS days
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
) t;


-- ---------------------------------------------------------------------
-- J. IMPACT OF THE "LATE" DEFINITION
-- Compares the two ways of defining a late order. The difference is the
-- number of orders delivered on the promised day, which a raw timestamp
-- comparison would wrongly label as late.
-- ---------------------------------------------------------------------
SELECT 'J. late definition' AS section,
       COUNT(*) AS delivered_orders,
       COUNT(*) FILTER (WHERE order_delivered_customer_date > order_estimated_delivery_date)
           AS late_by_timestamp,
       COUNT(*) FILTER (WHERE order_delivered_customer_date::date > order_estimated_delivery_date::date)
           AS late_by_date,
       ROUND(100.0 * COUNT(*) FILTER (WHERE order_delivered_customer_date > order_estimated_delivery_date) / COUNT(*), 2)
           AS pct_late_by_timestamp,
       ROUND(100.0 * COUNT(*) FILTER (WHERE order_delivered_customer_date::date > order_estimated_delivery_date::date) / COUNT(*), 2)
           AS pct_late_by_date
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;
