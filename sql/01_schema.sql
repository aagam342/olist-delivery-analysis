-- =====================================================================
-- 01_schema.sql
-- Olist Delivery Performance and Customer Satisfaction
--
-- Purpose : Create the nine raw tables in the "olist" database.
-- Run     : psql -U postgres -d olist -f sql/01_schema.sql
-- Note    : Safe to re-run. It drops and recreates all tables.
--
-- Design choices
--   * IDs and zip prefixes are TEXT. IDs are hash strings, and zip
--     prefixes can start with 0, which a numeric type would drop.
--   * Money columns use NUMERIC, never FLOAT, to avoid rounding errors.
--   * Primary keys are added only where the data guarantees uniqueness.
--     order_reviews has no primary key because review_id can repeat.
--   * Foreign keys are NOT added here. They are added in
--     04_constraints.sql after the data quality checks confirm that
--     the data is clean enough to support them.
--   * Table and column names match the CSV headers (including the
--     source spelling "lenght") so the load needs no renaming.
-- =====================================================================

DROP TABLE IF EXISTS order_payments CASCADE;
DROP TABLE IF EXISTS order_reviews CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS sellers CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS product_category_name_translation CASCADE;
DROP TABLE IF EXISTS geolocation CASCADE;

-- ---------------------------------------------------------------------
-- Dimension-like tables
-- ---------------------------------------------------------------------

CREATE TABLE customers (
    customer_id               TEXT PRIMARY KEY,   -- generated per order
    customer_unique_id        TEXT,               -- identifies the real customer
    customer_zip_code_prefix  TEXT,
    customer_city             TEXT,
    customer_state            TEXT
);

CREATE TABLE sellers (
    seller_id                 TEXT PRIMARY KEY,
    seller_zip_code_prefix    TEXT,
    seller_city               TEXT,
    seller_state              TEXT
);

CREATE TABLE product_category_name_translation (
    product_category_name          TEXT PRIMARY KEY,   -- Portuguese
    product_category_name_english  TEXT
);

-- NUMERIC is used for the descriptive columns because some CSV exports
-- write whole numbers as decimals (for example 40.0), which an INTEGER
-- column would reject during the load.
CREATE TABLE products (
    product_id                  TEXT PRIMARY KEY,
    product_category_name       TEXT,
    product_name_lenght         NUMERIC,
    product_description_lenght  NUMERIC,
    product_photos_qty          NUMERIC,
    product_weight_g            NUMERIC,
    product_length_cm           NUMERIC,
    product_height_cm           NUMERIC,
    product_width_cm            NUMERIC
);

-- Many rows per zip prefix. Not used in the analysis.
CREATE TABLE geolocation (
    geolocation_zip_code_prefix  TEXT,
    geolocation_lat              DOUBLE PRECISION,
    geolocation_lng              DOUBLE PRECISION,
    geolocation_city             TEXT,
    geolocation_state            TEXT
);

-- ---------------------------------------------------------------------
-- Fact-like tables
-- ---------------------------------------------------------------------

CREATE TABLE orders (
    order_id                        TEXT PRIMARY KEY,
    customer_id                     TEXT,
    order_status                    TEXT,
    order_purchase_timestamp        TIMESTAMP,
    order_approved_at               TIMESTAMP,
    order_delivered_carrier_date    TIMESTAMP,
    order_delivered_customer_date   TIMESTAMP,
    order_estimated_delivery_date   TIMESTAMP
);

-- One row per item. Composite key: an order can have several items.
CREATE TABLE order_items (
    order_id             TEXT,
    order_item_id        INTEGER,
    product_id           TEXT,
    seller_id            TEXT,
    shipping_limit_date  TIMESTAMP,
    price                NUMERIC(10,2),
    freight_value        NUMERIC(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

-- One row per payment entry. An order can be paid with several methods.
CREATE TABLE order_payments (
    order_id              TEXT,
    payment_sequential    INTEGER,
    payment_type          TEXT,
    payment_installments  INTEGER,
    payment_value         NUMERIC(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);

-- No primary key: review_id is not guaranteed unique in the source data.
CREATE TABLE order_reviews (
    review_id                TEXT,
    order_id                 TEXT,
    review_score             INTEGER,
    review_comment_title     TEXT,
    review_comment_message   TEXT,
    review_creation_date     TIMESTAMP,
    review_answer_timestamp  TIMESTAMP
);
