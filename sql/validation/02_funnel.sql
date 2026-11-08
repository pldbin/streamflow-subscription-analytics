-- =============================================================================
-- StreamFlow | validation 02 — conversion funnel
-- Purpose : rebuild the funnel from the "Users & Funnel" page in SQL.
--           A user counts at a stage if they have at least one transaction of
--           that type (Signup = every registered user).
-- Power BI: Signup 5,000 · Trial 3,831 (76.6%) · First Payment 3,602 (72.0%)
--           · Renewal 2,495 (49.9%) · Upgrade 535 (10.7%)
-- =============================================================================

-- 2.1 Funnel: users per stage, % of signups and step-to-step conversion
WITH
stage_users AS (
  SELECT 1 AS stage_order, 'Signup' AS stage, COUNT(*) AS users FROM users
  UNION ALL
  SELECT 2, 'Trial',         COUNT(DISTINCT user_id) FROM transactions WHERE transaction_type = 'trial_start'
  UNION ALL
  SELECT 3, 'First Payment', COUNT(DISTINCT user_id) FROM transactions WHERE transaction_type = 'first_payment'
  UNION ALL
  SELECT 4, 'Renewal',       COUNT(DISTINCT user_id) FROM transactions WHERE transaction_type = 'renewal'
  UNION ALL
  SELECT 5, 'Upgrade',       COUNT(DISTINCT user_id) FROM transactions WHERE transaction_type = 'upgrade'
)
SELECT
  stage,
  users,
  ROUND(100 * users / FIRST_VALUE(users) OVER (ORDER BY stage_order), 1) AS pct_of_signup,
  ROUND(100 * users / LAG(users) OVER (ORDER BY stage_order), 1)         AS step_conversion_pct
FROM stage_users
ORDER BY stage_order;


-- 2.2 Trial -> Paid by country (users who started a trial and later made a first payment)
-- Power BI (Users & Funnel page): total 64.0%
WITH
user_flags AS (
  SELECT
    user_id,
    MAX(transaction_type = 'trial_start')   AS has_trial,
    MAX(transaction_type = 'first_payment') AS has_paid
  FROM transactions
  GROUP BY user_id
)
SELECT
  u.country,
  SUM(f.has_trial)                                             AS trial_users,
  SUM(f.has_trial = 1 AND f.has_paid = 1)                      AS paid_with_trial,
  ROUND(100 * SUM(f.has_trial = 1 AND f.has_paid = 1) / SUM(f.has_trial), 1) AS trial_to_paid_pct
FROM user_flags f
JOIN users u ON u.user_id = f.user_id
GROUP BY u.country
ORDER BY trial_to_paid_pct DESC;


-- 2.3 Paid with vs without a trial
-- Power BI: 2,452 with trial, 1,150 without (direct pay share 31.9%)
WITH
user_flags AS (
  SELECT
    user_id,
    MAX(transaction_type = 'trial_start')   AS has_trial,
    MAX(transaction_type = 'first_payment') AS has_paid
  FROM transactions
  GROUP BY user_id
)
SELECT
  CASE WHEN has_trial = 1 THEN 'Paid with trial' ELSE 'Paid without trial' END AS path,
  COUNT(*)                                                                       AS paying_users,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                               AS share_pct
FROM user_flags
WHERE has_paid = 1
GROUP BY has_trial
ORDER BY has_trial DESC;
