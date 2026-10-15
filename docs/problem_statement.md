# Olist Delivery Performance and Customer Satisfaction: Problem Statement

| | |
|---|---|
| **Project** | Olist delivery performance and customer satisfaction analysis |
| **Dataset** | Brazilian E-Commerce Public Dataset by Olist (Kaggle) |
| **Tools** | PostgreSQL, Python (pandas, seaborn, scipy), Power BI |
| **Document status** | Draft v1, written before data loading. Items marked *To confirm* are verified during the data quality phase and recorded in `docs/data_quality_notes.md`. |

---

## 1. Context

Olist is a Brazilian e-commerce marketplace. Small and mid-sized sellers list their products on the Olist store, and customers buy from them. When an order is placed, the seller is notified and ships the product to the customer through a logistics partner. After the customer receives the product, or once the estimated delivery date has passed, the customer is sent a satisfaction survey and can rate the experience from 1 to 5.

The public dataset contains roughly 100,000 orders placed between 2016 and 2018 (exact date range *to confirm*), spread across nine related tables: orders, order items, customers, sellers, products, payments, reviews, geolocation, and a product category translation table. The data is anonymized.

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

| Decision | Choice | Rationale | Trade-off | Status |
|---|---|---|---|---|
| Order scope | Orders with status `delivered` and a non-null customer delivery date | Lateness is only defined once an order has actually been delivered. | Canceled, unavailable, and in-transit orders are excluded; the excluded count will be documented. | Final |
| Definition of "late" | Delivery date is later than the estimated delivery date, compared at **date level** (time of day ignored) | The estimated date is typically stored without a time (midnight), while the delivery date has a full timestamp. Comparing raw timestamps would flag an order delivered on the promised day, in the afternoon, as late. | Slightly more lenient than a strict timestamp comparison. | Final (confirm timestamp format in data quality phase) |
| Seller attribution | An order counts toward **every seller** who has an item in that order | Simple and keeps all data in the seller analysis. | In multi-seller orders, one seller's delay is counted against the others as well, which can overstate blame. | Provisional. Revisit after measuring the share of multi-seller orders. |
| Review handling | One review per order: the **most recent** by creation date | Some orders have more than one review; a single value per order keeps order-level averages correct. | Earlier reviews are ignored. | Final (confirm duplicate counts in data quality phase) |
| Revenue measure | Sum of item `price`, excluding freight | Isolates product revenue; freight is tracked separately. | Total customer spend is understated if freight is considered revenue. | Final |
| Seller ranking threshold | Sellers need a minimum number of delivered orders to be ranked | Without a floor, a seller with one late order would show a 100% late rate and distort the ranking. | Very small sellers are not evaluated. | Provisional. Threshold set after inspecting the distribution of orders per seller. |
| Time window | Full available period; incomplete months at the start and end are flagged and excluded from trend charts | The earliest and latest months in the data are sparse and would distort trends. | Fewer data points in the trend view. | Provisional (confirm after checking monthly order counts) |
| Fact table grain (Power BI) | One row per order item | Items link directly to products and sellers, which keeps the star schema simple. | Order-level measures need distinct counts to avoid double counting. | Final |
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

| Caveat | Why it matters | Planned handling | Status |
|---|---|---|---|
| `customer_id` is generated per order; `customer_unique_id` identifies the actual customer | Using the wrong key miscounts customers and repeat behavior | Use `customer_unique_id` whenever customer-level analysis is needed | To confirm |
| Orders can include items from more than one seller | Delay attribution to a single seller is ambiguous | See the seller attribution decision above | To confirm |
| Some orders have more than one review, and `review_id` may not be unique | Duplicates inflate review counts and skew averages | Keep the latest review per order | To confirm |
| Not all orders are delivered | Lateness is undefined for undelivered orders | Restrict to delivered orders and document exclusions | To confirm |
| Some delivered orders may have a missing delivery date | Late flag cannot be computed | Exclude and document the count | To confirm |
| Estimated delivery date may lack a time component | Naive timestamp comparison could mislabel same-day deliveries | Compare at date level | To confirm |
| Category names are in Portuguese; some may lack a translation | English labels are needed for reporting | Join the translation table; label missing ones as "unknown" | To confirm |
| The first and last months of the data are sparse | Distorts trend and growth metrics | Exclude partial months from trend views | To confirm |
| The geolocation table has many rows per zip prefix | Joining it directly would duplicate rows | Use customer and seller state columns instead of joining geolocation | To confirm |

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

## 10. Success Criteria

- Every number in the final report can be traced to a documented query or measure.
- Headline metrics (late rate, average review score, order count) match across SQL, Python, and Power BI.
- Every analytical decision in section 5 has a written rationale.
- The final recommendations name specific sellers, regions, or categories and quantify the expected impact.
