# KPI Definitions

This file is the single source of truth for every metric in the project. The SQL queries, the Python notebook, and the Power BI measures must all follow these definitions. If a definition changes, it is changed here first.

## 1. Design Rules

Every metric is defined by three things. Writing them down prevents most reporting errors.

| Rule | What it means | Example |
|---|---|---|
| **Grain** | The level at which the metric is calculated | Late rate is calculated per order, not per item |
| **Numerator and denominator** | What is counted, and out of what | Late rate = late orders / delivered orders |
| **Filters** | Which rows are included | Only delivered orders with a delivery date |

## 2. Base Definitions

These are used by most KPIs below.

**Delivered scope.** An order is in scope when its status is `delivered` and its customer delivery date is not null.

```sql
order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL
```

**Late flag (order level).** An order is late when it was delivered on a later calendar date than the estimated delivery date. The comparison is done on dates, not timestamps, because the estimated date usually has no time component.

```sql
CASE WHEN order_delivered_customer_date::date > order_estimated_delivery_date::date
     THEN 1 ELSE 0 END
```

**Delay days (late orders only).**

```sql
order_delivered_customer_date::date - order_estimated_delivery_date::date
```

**Review score per order.** When an order has more than one review, the most recent one (by `review_creation_date`) is used. Orders without a review are excluded from review-based metrics, not counted as zero.

```sql
SELECT DISTINCT ON (order_id) order_id, review_score
FROM order_reviews
ORDER BY order_id, review_creation_date DESC;
```

## 3. KPI Catalogue

### 3.1 Volume and Revenue

| KPI | Definition | Grain | Filters | Notes |
|---|---|---|---|---|
| **Total Orders** | Count of distinct `order_id` | Order | Delivered scope | Use a distinct count; items repeat the order ID. |
| **Total Revenue** | Sum of `price` from order items | Order item | Delivered scope | Excludes `freight_value`. Currency is BRL. |
| **Average Order Value** | Total Revenue / Total Orders | Order | Delivered scope | |

### 3.2 Delivery Performance

| KPI | Definition | Grain | Filters | Notes |
|---|---|---|---|---|
| **Late Orders** | Count of distinct orders where the late flag = 1 | Order | Delivered scope | |
| **Late Delivery Rate** | Late Orders / Total Orders | Order | Delivered scope | Headline delivery KPI. Always show it with the order count, because small groups produce unstable rates. |
| **Average Delivery Days** | Average of (delivery date minus purchase date), in days | Order | Delivered scope | Check for extreme values before reporting. |
| **Average Delay Days** | Average delay days across late orders only | Order | Delivered scope, late = 1 | Not defined for on-time orders. |
| **Estimated vs Actual Gap** | Average of (estimated date minus delivery date), in days | Order | Delivered scope | Positive means delivered earlier than promised. Shows whether estimates are padded. |

### 3.3 Customer Satisfaction

| KPI | Definition | Grain | Filters | Notes |
|---|---|---|---|---|
| **Average Review Score** | Average of review score per order | Order | Delivered scope, has review | Uses the latest review per order. |
| **Low-Score Rate** | Orders with score 1 or 2 / orders with a review | Order | Delivered scope, has review | Often more informative than the average because it captures dissatisfaction directly. |
| **Review Score (Late)** | Average Review Score where late flag = 1 | Order | Delivered scope, has review | |
| **Review Score (On-Time)** | Average Review Score where late flag = 0 | Order | Delivered scope, has review | |
| **Review Impact** | Review Score (On-Time) minus Review Score (Late) | Order | Delivered scope, has review | Headline impact KPI, in score points. Positive means late orders score lower. |

### 3.4 Revenue Exposure

| KPI | Definition | Grain | Filters | Notes |
|---|---|---|---|---|
| **Revenue on Late Orders** | Sum of `price` for orders where late flag = 1 | Order item | Delivered scope | Measures revenue exposure, not revenue lost. |
| **Late Revenue Share** | Revenue on Late Orders / Total Revenue | Order item | Delivered scope | |

### 3.5 Seller Performance

| KPI | Definition | Grain | Filters | Notes |
|---|---|---|---|---|
| **Seller Orders** | Distinct delivered orders containing at least one item from the seller | Seller and order | Delivered scope | An order with several sellers counts once for each seller. |
| **Seller Late Rate** | Late orders of the seller / Seller Orders | Seller and order | Delivered scope | Only sellers above the minimum order threshold are ranked. |
| **Seller Rank** | Rank of sellers by Seller Late Rate (descending) | Seller | Above minimum order threshold | Break ties by number of late orders. |
| **Late Order Share** | Seller's late orders / all late orders | Seller | Delivered scope | Used for the cumulative (Pareto) view. |

### 3.6 Trend

| KPI | Definition | Grain | Filters | Notes |
|---|---|---|---|---|
| **Month-over-Month Growth** | (This month minus previous month) / previous month | Month | Complete months only | Applied to orders and revenue. Month is based on the purchase date. |
| **Year-over-Year Growth** | (This month minus same month last year) / same month last year | Month | Complete months only | Only available where a prior-year month exists. |

## 4. Segmentation Dimensions

Metrics above are broken down by the following. Every segmented rate is shown together with its order count.

| Dimension | Source | Notes |
|---|---|---|
| Customer state | `customers.customer_state` | Used for the regional view. |
| Seller | `sellers.seller_id` | Seller state is available as a secondary dimension. |
| Product category | `products.product_category_name`, translated to English | Missing translations are labeled "unknown". |
| Purchase month | `orders.order_purchase_timestamp` | Used for trends. |
| Delay bucket | Derived from delay days | For example: 1 to 3, 4 to 7, 8 to 14, 15 or more days. |

## 5. Validation Plan

Metrics are validated across tools before anything is published.

| Check | Expectation |
|---|---|
| Total Orders in SQL vs Power BI | Identical |
| Late Delivery Rate in SQL vs Python vs Power BI | Identical to two decimal places |
| Average Review Score in SQL vs Python vs Power BI | Identical to two decimal places |
| Sum of seller-level Seller Orders vs Total Orders | Seller total is greater than or equal to Total Orders (multi-seller orders are counted for each seller) |
| Segment totals (for example by state) vs overall total | Segments add up to the total for additive metrics |

## 6. Change Log

| Date | Change |
|---|---|
| Initial version | First draft of all KPI definitions |
