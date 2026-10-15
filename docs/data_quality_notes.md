# Data Quality Notes

This document records what was found when the Olist data was loaded and checked, and what was decided as a result. Every number comes from `sql/03_data_quality_checks.sql` (output saved in `outputs/dq_results.txt`).

| | |
|---|---|
| **Database** | PostgreSQL 18, database `olist` |
| **Load method** | `psql \copy` from `data/raw/*.csv` (see `sql/02_load_data.sql`) |
| **Checks run** | October 2026 |
| **Outcome** | Data is clean enough to proceed. No orphan records, no invalid review scores, and only a handful of missing or inconsistent dates. All issues are small and have a documented handling rule. |

---

## 1. Load Verification

| Table | CSV rows | Database rows | Match |
|---|---|---|---|
| customers | 99,441 | 99,441 | Yes |
| sellers | 3,095 | 3,095 | Yes |
| product_category_name_translation | 71 | 71 | Yes |
| products | 32,951 | 32,951 | Yes |
| geolocation | 1,000,163 | 1,000,163 | Yes |
| orders | 99,441 | 99,441 | Yes |
| order_items | 112,650 | 112,650 | Yes |
| order_payments | 103,886 | 103,886 | Yes |
| order_reviews | 99,224 | 99,224 | Yes |

**Result:** all nine tables loaded completely. The row count of every table in the database equals the row count of its source CSV file (counted with pandas, which handles the multi-line review comments correctly).

Internal consistency checks that already hold: customers and orders have the same row count (99,441), and the review counts reconcile (see section 2, findings 1 and 2).

## 2. Findings

| # | Check | Result | Decision |
|---|---|---|---|
| 1 | Review IDs that appear more than once | 789 | `review_id` is not a reliable key. Reviews are de-duplicated by `order_id`. |
| 2 | Orders with more than one review | 547 (543 with two reviews, 4 with three) | Keep the most recent review per order by `review_creation_date`. |
| 3 | `customer_id` vs `customer_unique_id` (distinct counts) | 99,441 vs 96,096 | `customer_id` is generated per order. Use `customer_unique_id` for any customer-level analysis. |
| 4 | Delivered orders with a missing delivery date | 8 | Excluded from lateness metrics. |
| 5 | Orders by status | 96,478 delivered (97.0%); 2,963 other (shipped 1,107, canceled 625, unavailable 609, invoiced 314, processing 301, created 5, approved 2) | Only delivered orders are in scope. |
| 6 | Products with a missing category | 610 | Labeled "unknown" in reporting. |
| 7 | Categories without an English translation | 2 (`portateis_cozinha_e_preparadores_de_alimentos`, 10 products; `pc_gamer`, 3 products) | Labeled "unknown". Only 13 products are affected, so the impact is negligible. |
| 8 | Orphan records (six relationships) | 0 in every relationship | Foreign keys can be added (`sql/04_constraints.sql`). |
| 9 | Delivery date before purchase date | 0 | None needed. |
| 10 | Delivery date before carrier handover date | 23 | Kept. The delivery date is valid for lateness. The carrier date is not used in the core KPIs; any later analysis that uses it excludes these 23 orders. |
| 11 | Estimated delivery date has a time component | 0 of 99,441 orders (every estimate is at 00:00:00) | Confirms the date-level comparison for the "late" flag. |
| 12 | Delivery timestamps with a time component | All 96,476 non-null delivery dates have a time of day | Confirms the mismatch between estimate (date only) and delivery (full timestamp). |
| 13 | Multi-seller share of delivered orders | 1.32% (1,275 of 96,470) | The attribution rule (count an order for every seller on it) is kept. |
| 14 | Review scores outside 1 to 5, or missing | None found | None needed. |
| 15 | Orders with no review | 768 (646 of them inside the delivered scope) | Excluded from review-based metrics, not counted as zero. |
| 16 | Orders with no items | 775, none inside the delivered scope | Not an issue for the analysis (see below). |
| 17 | Orders with no payment | 1 | Not used; revenue is based on item price. |

**Note on finding 16.** The delivered-scope order count is 96,470 both with and without a join to `order_items` (section 4 below and section 5), which shows that every in-scope order has at least one item. The 775 orders without items fall outside the scope.

**Note on findings 1 and 2.** 789 review IDs repeat, which is more than the 547 orders that have multiple reviews. This suggests that some review IDs are shared across different orders, so `review_id` cannot identify a review. Joining or grouping on `order_id` is the safe approach.

## 3. Date Range

| Item | Value |
|---|---|
| First purchase | 2016-09-04 |
| Last purchase | 2018-10-17 |
| First delivery | 2016-10-11 |
| Last delivery | 2018-10-17 |
| Latest estimated delivery date | 2018-11-12 |

**Orders per purchase month**

| Month | Orders | | Month | Orders |
|---|---|---|---|---|
| 2016-09 | 4 | | 2018-01 | 7,269 |
| 2016-10 | 324 | | 2018-02 | 6,728 |
| 2016-11 | none | | 2018-03 | 7,211 |
| 2016-12 | 1 | | 2018-04 | 6,939 |
| 2017-01 | 800 | | 2018-05 | 6,873 |
| 2017-02 | 1,780 | | 2018-06 | 6,167 |
| 2017-03 | 2,682 | | 2018-07 | 6,292 |
| 2017-04 | 2,404 | | 2018-08 | 6,512 |
| 2017-05 | 3,700 | | 2018-09 | 16 |
| 2017-06 | 3,245 | | 2018-10 | 4 |
| 2017-07 | 4,026 | | | |
| 2017-08 | 4,331 | | | |
| 2017-09 | 4,285 | | | |
| 2017-10 | 4,631 | | | |
| 2017-11 | 7,544 | | | |
| 2017-12 | 5,673 | | | |

**Sparse months:** September, October, and December 2016 (4, 324, and 1 orders, with no orders in November 2016), and September and October 2018 (16 and 4 orders). Together these 349 orders are 0.35% of all orders.

**Decision on partial months:** trend charts and growth metrics use **January 2017 to August 2018**. Headline KPIs (late rate, review score, revenue) use all delivered orders in scope, so they include the 2016 and late 2018 orders. Consequences:

- Month-over-month growth starts in February 2017, because December 2016 has only one order.
- Year-over-year growth is only available for January to August 2018.
- Volume grew strongly through 2017, so monthly trends mix marketplace growth with changes in delivery performance. Rates (late %, review score) are more comparable over time than counts.

## 4. Scope Waterfall

| Step | Orders | Removed at this step |
|---|---|---|
| 1. All orders | 99,441 | n/a |
| 2. Status = delivered | 96,478 | 2,963 |
| 3. Delivered with delivery date | 96,470 | 8 |
| 4. And has at least one review | 95,824 | 646 |

The lateness metrics use step 3 (96,470 orders, 97.0% of all orders). Review-based metrics use step 4 (95,824 orders).

## 5. Impact of the "Late" Definition

| Definition | Late orders | Late rate |
|---|---|---|
| Raw timestamp comparison | 7,826 | 8.11% |
| Date-level comparison (used in this project) | 6,534 | 6.77% |

**Interpretation:** the estimated delivery date is always at midnight, while delivery dates carry a time of day. A raw timestamp comparison would label every order delivered on the promised day as late. That affects 1,292 orders and inflates the late rate by 1.34 percentage points (8.11% vs 6.77%). The date-level rule treats delivery on the promised day as on time.

**Baseline:** 6.77% of delivered orders (6,534 of 96,470) arrive after the estimated delivery date. This is the figure the later analysis breaks down by seller, region, and category.

## 6. Seller Threshold

Delivered orders per seller (2,970 sellers have at least one delivered order in scope; the median is 7 orders and the maximum is 1,819).

| Minimum delivered orders | Sellers remaining | Share of the 2,970 sellers |
|---|---|---|
| 10 or more | 1,237 | 41.7% |
| 30 or more | 627 | 21.1% |
| 50 or more | 425 | 14.3% |
| 100 or more | 210 | 7.1% |

**Chosen threshold: 50 delivered orders.**

**Reason:** a seller's late rate is noisy when the order count is small. With an overall late rate of about 6.8%, the standard error of a seller's rate is roughly 4.6 percentage points at 30 orders, 3.6 at 50, and 2.5 at 100. A threshold of 50 keeps 425 sellers, which is enough for a meaningful ranking, without letting a few unlucky orders decide a seller's position.

**Follow-up in the analysis phase:** check how much of the total order volume and late-order volume the 425 sellers cover, and test whether the top of the ranking changes at thresholds of 30 and 100. Sellers below the threshold are not ranked, but their orders still count in all totals.

## 7. Delivery Time Distribution

Days from purchase to delivery, for the 96,470 orders in scope.

| Minimum | Median | 95th percentile | 99th percentile | Maximum |
|---|---|---|---|---|
| 0 | 10 | 29 | 46 | 210 |

**Outlier handling:** extreme values are kept. The long tail (a maximum of 210 days against a 99th percentile of 46) reflects real, very late deliveries and is part of the problem being studied. Reports show the median and percentiles next to the average, because the average is pulled up by the tail.

## 8. Reviews Overview (before de-duplication)

| Score | Reviews | Share |
|---|---|---|
| 1 | 11,424 | 11.5% |
| 2 | 3,151 | 3.2% |
| 3 | 8,179 | 8.2% |
| 4 | 19,142 | 19.3% |
| 5 | 57,328 | 57.8% |
| **Total** | **99,224** | |

Scores 1 and 2 together are 14.7% of all reviews, and the average score is about 4.09. These are review-level figures before keeping one review per order; the order-level figures will be calculated in the analysis phase.

Review distribution per order: 98,126 orders have one review, 543 have two, and 4 have three.

## 9. Updates to the Problem Statement

| Item in problem statement | New status | Evidence |
|---|---|---|
| Order scope | Final | 96,470 orders (97.0% of all orders) |
| Late definition (date level) | Final | Estimates have no time component in 100% of rows; effect is 8.11% vs 6.77% |
| Seller attribution rule | Final | Multi-seller share is 1.32% (1,275 orders) |
| Review handling | Final | 547 orders have multiple reviews; 789 review IDs repeat |
| Seller ranking threshold | Final: 50 orders | 425 sellers retained; sensitivity check planned |
| Time window | Final | Trends use January 2017 to August 2018; 349 orders fall outside |
| Data caveats table | All items updated with evidence | See section 2 above |
