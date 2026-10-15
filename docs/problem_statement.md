# Olist Delivery Performance and Customer Satisfaction: Problem Statement

| | |
|---|---|
| **Project** | Olist delivery performance and customer satisfaction analysis |
| **Dataset** | Brazilian E-Commerce Public Dataset by Olist (Kaggle) |
| **Tools** | PostgreSQL, Python (pandas, seaborn, scipy), Power BI |
| **Document status** | Draft v2, updated after the data quality checks. Evidence for every decision is in [`data_quality_notes.md`](data_quality_notes.md). |

---

## 1. Context

Olist is a Brazilian e-commerce marketplace. Small and mid-sized sellers list their products on the Olist store, and customers buy from them. When an order is placed, the seller is notified and ships the product to the customer through a logistics partner. After the customer receives the product, or once the estimated delivery date has passed, the customer is sent a satisfaction survey and can rate the experience from 1 to 5.

The public dataset contains 99,441 orders placed between September 2016 and October 2018, spread across nine related tables: orders, order items, customers, sellers, products, payments, reviews, geolocation, and a product category translation table. The data is anonymized. Order volume is very low before 2017 and after August 2018, so trend analysis focuses on January 2017 to August 2018.

Delivery is the part of the experience that the marketplace controls least and the customer notices most. When an order arrives later than promised, the customer's rating is likely to suffer, and ratings influence repeat purchases and seller reputation. This project measures how large that effect is and where it comes from.

## 2. Business Question

**Primary question**

> Which sellers, regions, and product categories cause late deliveries, and how much do late deliveries hurt customer review scores and revenue?

**Supporting questions**

1. What share of delivered orders arrive after the estimated delivery date, and how has this changed over time?
2. Are late deliveries concentrated in a small number of sellers?
3. Which customer states (regions) and product categories have the highest late delivery rates?
4. By how much do review scores fall when an order is late, and does the drop grow with the length of the delay?
5. How much revenue is attached to late orders, and which segments carry most of that exposure?

**Starting point.** Across all delivered orders in scope, 6.77% (6,534 of 96,470) arrive after the estimated delivery date. The analysis breaks this baseline down by seller, region, category, and time.

## 3. Stakeholders and Decisions Supported

| Stakeholder | Decision this analysis supports |
|---|---|
| Seller management | Which sellers to coach, penalize, or remove based on delivery performance |
| Logistics and operations | Which regions and routes need carrier or fulfilment improvements |
| Customer experience | Whether estimated delivery dates should be adjusted for specific regions or categories |
| Category managers | Which categories carry the highest delivery risk and need special handling |

## 4. Hypotheses

Each hypothesis is a testable guess. The analysis will confirm or reject it, and the outcome will be recorded in the final report.

| ID | Hypothesis | How it will be tested | Status |
|---|---|---|---|
| H1 | Late orders receive lower review scores than on-time orders. | Compare average score and share of low scores (1 to 2) by late flag in SQL; confirm with a Mann-Whitney U test in Python. | Open |
| H2 | A small share of sellers accounts for a large share of late orders. | Rank sellers by late orders and build a cumulative (Pareto) share in SQL. | Open |
| H3 | Late delivery rates differ materially across customer states. | State-level late rate in SQL; map and bar chart in Power BI. | Open |
| H4 | Late delivery rates differ materially across product categories. | Category-level late rate in SQL, with a minimum order volume filter. | Open |
| H5 | The longer the delay, the lower the review score. | Bucket delay days (for example 1 to 3, 4 to 7, 8 to 14, 15+) and compare average score per bucket. | Open |

## 5. Scope and Analytical Decisions

All decisions below were checked against the loaded data. Evidence and numbers are in [`data_quality_notes.md`](data_quality_notes.md).

| Decision | Choice | Rationale | Trade-off | Status |
|---|---|---|---|---|
| Order scope | Orders with status `delivered` and a non-null customer delivery date: **96,470 of 99,441 orders (97.0%)** | Lateness is only defined once an order has actually been delivered. Of the 96,478 delivered orders, 8 have no delivery date. | The remaining 2,971 orders (canceled, shipped, unavailable, and other statuses, plus the 8 above) are excluded from lateness metrics. | Final |
| Definition of "late" | Delivery date is later than the estimated delivery date, compared at **date level** (time of day ignored) | Every estimated date is at midnight (0 of 99,441 have a time of day), while delivery dates carry a full timestamp. A raw comparison would label orders delivered on the promised day as late: it gives 8.11% late (7,826 orders) against 6.77% (6,534 orders) at date level, a difference of 1,292 orders. | Slightly more lenient than a strict timestamp comparison. | Final |
| Seller attribution | An order counts toward **every seller** who has an item in that order | Only 1.32% of delivered orders (1,275 of 96,470) involve more than one seller, so the distortion is small and the rule keeps all data in the seller analysis. | In those 1,275 orders, one seller's delay is counted against the other sellers as well. | Final |
| Review handling | One review per order: the **most recent** by creation date | 547 orders have more than one review, and 789 review IDs repeat, so `review_id` cannot be used as a key. | Earlier reviews are ignored. Orders without a review (646 in scope) are excluded from review metrics, not scored as zero. | Final |
| Revenue measure | Sum of item `price`, excluding freight | Isolates product revenue; freight is tracked separately. | Total customer spend is understated if freight is considered revenue. | Final |
| Seller ranking threshold | Sellers need at least **50 delivered orders** to be ranked | With a late rate near 6.8%, a seller's measured rate has a standard error of about 3.6 percentage points at 50 orders (4.6 at 30). A threshold of 50 keeps 425 of 2,970 sellers, a workable ranking without letting a few orders decide a position. | Sellers below the threshold are not ranked, but their orders still count in all totals. | Final, with a sensitivity check at 30 and 100 orders planned |
| Time window | Trends and growth metrics cover **January 2017 to August 2018**. Headline KPIs use all delivered orders in scope. | The first four months of data (2016) and the last two (September and October 2018) are sparse: 349 orders in total (0.35%), with none in November 2016. | Month-over-month growth starts in February 2017, and year-over-year growth is only available for January to August 2018. | Final |
| Fact table grain (Power BI) | One row per order item | Items link directly to products and sellers, which keeps the star schema simple. | Order-level measures need distinct counts to avoid double counting. | Final |
| Missing categories | Products with a missing category (610) or without an English translation (13 products in 2 categories) are labeled "unknown" | Keeps every product in the category view. | Those 13 products lose their original category name; the effect is negligible. | Final |
| Currency | Brazilian real (BRL), no conversion | The dataset is in one currency. | Not directly comparable with other markets. | Final |

## 6. Key Performance Indicators

The full definitions, formulas, and logic for each metric are in [`kpi_definitions.md`](kpi_definitions.md). That file is the single source of truth. The metrics used are:

- Total Orders and Total Revenue
- Late Delivery Rate
- Average Delivery Days and Average Delay Days
- Average Review Score
- Review Impact (on-time average minus late average) and Low-Score Rate
- Revenue on Late Orders and its share of total
- Seller Late Rate and Seller Rank
- Month-over-month and year-over-year growth

## 7. Known Data Caveats

All caveats below were tested against the loaded data (see [`data_quality_notes.md`](data_quality_notes.md)).

| Caveat | Why it matters | Handling | Evidence | Status |
|---|---|---|---|---|
| `customer_id` is generated per order; `customer_unique_id` identifies the actual customer | Using the wrong key miscounts customers and repeat behavior | Use `customer_unique_id` for any customer-level analysis | 99,441 `customer_id` values vs 96,096 `customer_unique_id` values | Confirmed |
| Orders can include items from more than one seller | Delay attribution to a single seller is ambiguous | See the seller attribution decision | 1.32% of delivered orders | Confirmed |
| Some orders have more than one review, and `review_id` is not unique | Duplicates inflate review counts and skew averages | Keep the latest review per order | 547 orders with multiple reviews; 789 repeated review IDs | Confirmed |
| Not all orders are delivered | Lateness is undefined for undelivered orders | Restrict to delivered orders and document exclusions | 96,478 of 99,441 orders are delivered | Confirmed |
| Some delivered orders have no delivery date | The late flag cannot be computed | Exclude and document the count | 8 orders | Confirmed |
| Estimated delivery date has no time component | A raw timestamp comparison would mislabel same-day deliveries | Compare at date level | 0 of 99,441 estimates have a time of day | Confirmed |
| Some orders have no review | Review metrics cannot be computed for them | Exclude from review metrics | 646 delivered orders in scope | Confirmed |
| A few delivery dates precede the carrier handover date | The sequence of dates is inconsistent | Keep for lateness; exclude from any carrier-date analysis | 23 orders | Confirmed |
| Category names are in Portuguese; some are missing or untranslated | English labels are needed for reporting | Join the translation table; label the rest "unknown" | 610 products without a category; 2 categories without a translation | Confirmed |
| The first and last months of the data are sparse | Distorts trend and growth metrics | Limit trend views to January 2017 to August 2018 | 349 orders in the sparse months | Confirmed |
| Delivery times have a long tail | The average is pulled up by a few very late orders | Report the median and percentiles alongside the average | Median 10 days, 99th percentile 46 days, maximum 210 days | Confirmed |
| The geolocation table has a very large number of rows | Joining it directly could multiply rows | Not used; state columns from `customers` and `sellers` cover the regional analysis | 1,000,163 rows | Not used in this project |

## 8. Deliverables

1. **PostgreSQL analysis:** schema, data quality checks, and about 15 documented analysis queries covering delivery KPIs, seller performance, region and category analysis, review impact, and trends.
2. **Python notebook:** data cleaning, exploratory charts (seaborn), and a statistical test on the review score gap.
3. **Power BI report:** star schema model with a date table, DAX measures, and a four-page dashboard (Overview, Delivery Performance, Seller Scorecard with drill-through, Insights).
4. **Written findings:** three to five quantified findings with recommendations.
5. **GitHub repository:** README, documentation, SQL scripts, notebook, and dashboard screenshots.

## 9. Limitations

- **Correlation, not causation.** Late orders may differ from on-time orders in other ways (product type, seller, distance), so the review score gap is an association.
- **No cost data.** The dataset has no carrier or penalty costs, so the financial impact is expressed as revenue exposure, not profit.
- **Historical data.** The data covers 2016 to 2018; recommendations are illustrative and show the method, not current Olist performance.
- **Survey bias.** Only customers who answered the survey have a review score, and they may not represent all customers.
- **Growth in volume.** Order volume grew strongly through 2017, so monthly counts reflect marketplace growth as well as performance. Rates are more comparable over time than counts.

## 10. Success Criteria

- Every number in the final report can be traced to a documented query or measure.
- Headline metrics (late rate, average review score, order count) match across SQL, Python, and Power BI. Reference values: 96,470 orders in scope, 6,534 late orders, 6.77% late rate.
- Every analytical decision in section 5 has a written rationale backed by the data.
- The final recommendations name specific sellers, regions, or categories and quantify the expected impact.
