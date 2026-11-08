-- =============================================================================
-- StreamFlow | validation 03 — cohort retention
-- Purpose : rebuild the cohort matrix and the retention curve from the
--           "Retention" page in SQL.
-- Definitions (same as the DAX model):
--   cohort        = calendar month of signup
--   month_offset  = calendar months between the cohort month and the payment month
--                   (DATEDIFF(..., MONTH) in DAX, PERIOD_DIFF here)
--   active payer  = user with a first_payment, renewal or upgrade in that month
--   retention %   = active payers / cohort size
-- =============================================================================

-- 3.1 Cohort matrix in long format (one row per cohort x month offset)
-- Power BI matrix: e.g. cohort 2024-02 -> M0 71.6%, M1 53.7%, M12 46.3% (190 rows)
WITH
cohorts AS (
  SELECT DATE_FORMAT(signup_date, '%Y-%m') AS cohort_month, COUNT(*) AS cohort_size
  FROM users
  GROUP BY DATE_FORMAT(signup_date, '%Y-%m')
),
payments AS (
  SELECT
    DATE_FORMAT(u.signup_date, '%Y-%m') AS cohort_month,
    PERIOD_DIFF(DATE_FORMAT(t.date, '%Y%m'), DATE_FORMAT(u.signup_date, '%Y%m')) AS month_offset,
    t.user_id
  FROM transactions t
  JOIN users u ON u.user_id = t.user_id
  WHERE t.transaction_type IN ('first_payment', 'renewal', 'upgrade')
)
SELECT
  p.cohort_month,
  p.month_offset,
  c.cohort_size,
  COUNT(DISTINCT p.user_id)                              AS active_payers,
  ROUND(100 * COUNT(DISTINCT p.user_id) / c.cohort_size, 1) AS retention_pct
FROM payments p
JOIN cohorts c ON c.cohort_month = p.cohort_month
GROUP BY p.cohort_month, p.month_offset, c.cohort_size
ORDER BY p.cohort_month, p.month_offset;


-- 3.2 Weighted retention curve (all cohorts together)
-- For month k only cohorts that are old enough to have a month k are counted
-- in the denominator (same logic as the DAX measure [Retention Curve %]).
-- Power BI curve, M0..M12 (chart labels rounded to whole %):
--   64.2 · 49.1 · 44.5 · 48.9 · 45.6 · 42.0 · 42.6 · 36.8 · 34.8 · 35.6 · 35.0 · 34.0 · 42.9 %
WITH
last_month AS (
  SELECT DATE_FORMAT(MAX(date), '%Y%m') AS yyyymm FROM transactions
),
cohorts AS (
  SELECT DATE_FORMAT(signup_date, '%Y%m') AS cohort_yyyymm, COUNT(*) AS cohort_size
  FROM users
  GROUP BY DATE_FORMAT(signup_date, '%Y%m')
),
payments AS (
  SELECT DISTINCT
    PERIOD_DIFF(DATE_FORMAT(t.date, '%Y%m'), DATE_FORMAT(u.signup_date, '%Y%m')) AS month_offset,
    t.user_id
  FROM transactions t
  JOIN users u ON u.user_id = t.user_id
  WHERE t.transaction_type IN ('first_payment', 'renewal', 'upgrade')
),
active AS (
  SELECT month_offset, COUNT(*) AS active_payers
  FROM payments
  GROUP BY month_offset
)
SELECT
  a.month_offset,
  a.active_payers,
  SUM(c.cohort_size)                                  AS eligible_users,
  ROUND(100 * a.active_payers / SUM(c.cohort_size), 1) AS retention_pct
FROM active a
CROSS JOIN last_month l
JOIN cohorts c
  ON PERIOD_DIFF(l.yyyymm, c.cohort_yyyymm) >= a.month_offset   -- cohort is old enough
GROUP BY a.month_offset, a.active_payers
ORDER BY a.month_offset;


-- 3.3 Active payers per calendar month (Overview page: Aug 2025 = 1,932)
SELECT
  DATE_FORMAT(date, '%Y-%m') AS month,
  COUNT(DISTINCT user_id)    AS active_payers
FROM transactions
WHERE transaction_type IN ('first_payment', 'renewal', 'upgrade')
GROUP BY DATE_FORMAT(date, '%Y-%m')
ORDER BY month;
