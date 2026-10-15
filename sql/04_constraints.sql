-- =====================================================================
-- 04_constraints.sql
-- Olist Delivery Performance and Customer Satisfaction
--
-- Purpose : Add foreign keys and indexes AFTER the data quality checks.
-- Run     : psql -U postgres -d olist -f sql/04_constraints.sql
--
-- Rules
--   * Run this only after section D of 03_data_quality_checks.sql shows
--     0 orphans for the relationships below. If a foreign key fails,
--     PostgreSQL reports which constraint broke. Investigate the
--     orphan rows first; do not remove the constraint to make it pass.
--   * No foreign key is added from products to the translation table,
--     because some categories are expected to be missing a translation.
--     That relationship is handled with a LEFT JOIN in the analysis.
--   * order_reviews.order_id is indexed but not a primary key, because
--     an order can have more than one review.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Foreign keys
-- ---------------------------------------------------------------------
ALTER TABLE orders
    ADD CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id);

ALTER TABLE order_items
    ADD CONSTRAINT fk_items_order
    FOREIGN KEY (order_id) REFERENCES orders (order_id);

ALTER TABLE order_items
    ADD CONSTRAINT fk_items_product
    FOREIGN KEY (product_id) REFERENCES products (product_id);

ALTER TABLE order_items
    ADD CONSTRAINT fk_items_seller
    FOREIGN KEY (seller_id) REFERENCES sellers (seller_id);

ALTER TABLE order_payments
    ADD CONSTRAINT fk_payments_order
    FOREIGN KEY (order_id) REFERENCES orders (order_id);

ALTER TABLE order_reviews
    ADD CONSTRAINT fk_reviews_order
    FOREIGN KEY (order_id) REFERENCES orders (order_id);

-- ---------------------------------------------------------------------
-- Indexes on columns used heavily in joins, filters, and grouping.
-- Primary keys are already indexed automatically.
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_orders_customer     ON orders (customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_status       ON orders (order_status);
CREATE INDEX IF NOT EXISTS idx_orders_purchase_ts  ON orders (order_purchase_timestamp);
CREATE INDEX IF NOT EXISTS idx_items_seller        ON order_items (seller_id);
CREATE INDEX IF NOT EXISTS idx_items_product       ON order_items (product_id);
CREATE INDEX IF NOT EXISTS idx_reviews_order       ON order_reviews (order_id);
CREATE INDEX IF NOT EXISTS idx_customers_state     ON customers (customer_state);
CREATE INDEX IF NOT EXISTS idx_products_category   ON products (product_category_name);

-- Refresh planner statistics so queries use the new indexes well.
ANALYZE;
