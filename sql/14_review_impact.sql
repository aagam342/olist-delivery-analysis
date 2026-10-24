
-- =====================================================================
-- 14_review_impact.sql
-- Theme D: Impact of late delivery on review scores
--
-- Source : v_delivered_orders, restricted to orders that have a review
--          (review_score IS NOT NULL): 95824 orders.
-- Note   : a low score means 1 or 2. Results show an association between
--          late delivery and review score, not proof of cause.
-- Run    : psql -U postgres -d olist -f sql/14_review_impact.sql -o outputs/14_review_impact_results.txt
-- =====================================================================


-- ---------------------------------------------------------------------
-- D1. Review score for late versus on-time orders
-- Question  : How much lower are review scores for late orders?
-- Output    : (1) two rows (on-time, late): delivery_status, reviewed_orders,
--                 avg_score, low_score_pct, one_star_pct
--             (2) one row: review_impact = average score of on-time orders
--                 minus average score of late orders (headline KPI)
-- Validation: reviewed_orders of the two groups add up to 95824.
-- ---------------------------------------------------------------------

-- (1) Late versus on-time
SELECT CASE WHEN is_late THEN 'Late' ELSE 'On-time' END AS delivery_status,
       COUNT(*)                                                                   AS reviewed_orders,
       ROUND(AVG(review_score), 2)                                                AS avg_score,
       ROUND(100.0 * COUNT(*) FILTER (WHERE review_score <= 2) / COUNT(*), 2)     AS low_score_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE review_score = 1) / COUNT(*), 2)      AS one_star_pct
FROM v_delivered_orders
WHERE review_score IS NOT NULL
GROUP BY is_late
ORDER BY is_late;

-- (2) Headline KPI: Review Impact
SELECT ROUND(AVG(review_score) FILTER (WHERE NOT is_late)
             - AVG(review_score) FILTER (WHERE is_late), 2) AS review_impact
FROM v_delivered_orders
WHERE review_score IS NOT NULL;


-- ---------------------------------------------------------------------
-- D2. Review score by length of delay (tests hypothesis H5)
-- Question  : Does the review score keep falling as the delay gets longer?
-- Output    : delay_bucket, reviewed_orders, avg_score, low_score_pct
-- Validation: reviewed_orders add up to 95824.
-- ---------------------------------------------------------------------
SELECT CASE
           WHEN days_vs_estimate <= 0              THEN 'On time or early'
           WHEN days_vs_estimate BETWEEN 1 AND 3   THEN 'Late 1-3 days'
           WHEN days_vs_estimate BETWEEN 4 AND 7   THEN 'Late 4-7 days'
           WHEN days_vs_estimate BETWEEN 8 AND 14  THEN 'Late 8-14 days'
           ELSE 'Late 15+ days'
       END                                                                    AS delay_bucket,
       COUNT(*)                                                               AS reviewed_orders,
       ROUND(AVG(review_score), 2)                                            AS avg_score,
       ROUND(100.0 * COUNT(*) FILTER (WHERE review_score <= 2) / COUNT(*), 2) AS low_score_pct
FROM v_delivered_orders
WHERE review_score IS NOT NULL
GROUP BY 1
ORDER BY MIN(days_vs_estimate);


-- ---------------------------------------------------------------------
-- D3. Score distribution for late versus on-time orders
-- Question  : How do the scores 1 to 5 split inside each group?
-- Output    : review_score (1 to 5), on_time_pct, late_pct
--             (each column is a share of its own group)
-- Validation: each of the two percentage columns adds up to 100.00.
-- ---------------------------------------------------------------------
SELECT review_score,
       ROUND(100.0 * COUNT(*) FILTER (WHERE NOT is_late)
             / SUM(COUNT(*) FILTER (WHERE NOT is_late)) OVER (), 2) AS on_time_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_late)
             / SUM(COUNT(*) FILTER (WHERE is_late)) OVER (), 2)     AS late_pct
FROM v_delivered_orders
WHERE review_score IS NOT NULL
GROUP BY review_score
ORDER BY review_score;
