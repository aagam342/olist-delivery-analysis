-- =====================================================================
-- 02_load_data.sql
-- Olist Delivery Performance and Customer Satisfaction
--
-- Purpose : Load the nine CSV files from data/raw into the tables
--           created by 01_schema.sql.
-- Run     : From the PROJECT ROOT folder (paths below are relative):
--             psql -U postgres -d olist -f sql/02_load_data.sql
--
-- Notes
--   * \copy is a psql command. It reads the file on YOUR computer with
--     YOUR permissions. The server-side COPY command would instead read
--     the file as the PostgreSQL service account, which usually has no
--     access to user folders on Windows.
--   * Each \copy must stay on ONE line (psql meta-commands cannot wrap).
--   * HEADER true skips the first row. Columns are matched by position,
--     so the table column order must match the CSV column order.
--   * In CSV mode, an empty unquoted value is loaded as NULL.
--   * Forward slashes in paths work on Windows.
-- =====================================================================

\echo Loading customers
\copy customers FROM 'data/raw/olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo Loading sellers
\copy sellers FROM 'data/raw/olist_sellers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo Loading product_category_name_translation
\copy product_category_name_translation FROM 'data/raw/product_category_name_translation.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo Loading products
\copy products FROM 'data/raw/olist_products_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo Loading geolocation (about one million rows, may take a moment)
\copy geolocation FROM 'data/raw/olist_geolocation_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo Loading orders
\copy orders FROM 'data/raw/olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo Loading order_items
\copy order_items FROM 'data/raw/olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo Loading order_payments
\copy order_payments FROM 'data/raw/olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo Loading order_reviews
\copy order_reviews FROM 'data/raw/olist_order_reviews_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo Load finished. Row counts:

SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'product_category_name_translation', COUNT(*) FROM product_category_name_translation
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews;
