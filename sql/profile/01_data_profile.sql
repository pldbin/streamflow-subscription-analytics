-- =============================================================================
-- StreamFlow | 01_data_profile.sql
-- Purpose : first look at the source database before any analysis —
--           size, time span, dimensions and data-quality checks.
-- Source  : MySQL database `streamflow` (4 tables), queried in DBeaver.
-- =============================================================================

-- 1. Table sizes ---------------------------------------------------------------
SELECT 'users'              AS table_name, COUNT(*) AS row_count FROM users
UNION ALL
SELECT 'transactions',       COUNT(*) FROM transactions
UNION ALL
SELECT 'subscription_plans', COUNT(*) FROM subscription_plans
UNION ALL
SELECT 'marketing_spend',    COUNT(*) FROM marketing_spend;

-- 2. Time span -----------------------------------------------------------------
SELECT 'users.signup_date'     AS field, MIN(signup_date) AS first_date, MAX(signup_date) AS last_date FROM users
UNION ALL
SELECT 'transactions.date',     MIN(DATE(date)), MAX(DATE(date)) FROM transactions
UNION ALL
SELECT 'marketing_spend.month', MIN(month), MAX(month) FROM marketing_spend;

-- 3. Dimensions (distinct values) ----------------------------------------------
SELECT
  COUNT(DISTINCT country)             AS countries,
  COUNT(DISTINCT platform)            AS platforms,
  COUNT(DISTINCT acquisition_channel) AS channels,
  COUNT(DISTINCT age_group)           AS age_groups
FROM users;

-- 4. Transaction mix -----------------------------------------------------------
SELECT
  transaction_type,
  COUNT(*)                AS transactions,
  ROUND(SUM(amount_usd), 2) AS amount_usd
FROM transactions
GROUP BY transaction_type
ORDER BY transactions DESC;

-- 5. Data-quality checks -------------------------------------------------------
-- 5.1 Primary keys are unique (duplicates should be 0)
SELECT 'users'        AS table_name, COUNT(*) - COUNT(DISTINCT user_id)        AS duplicate_keys FROM users
UNION ALL
SELECT 'transactions', COUNT(*) - COUNT(DISTINCT transaction_id) FROM transactions;

-- 5.2 Missing values that need a decision in the model
SELECT 'transactions.campaign IS NULL'           AS check_name, COUNT(*) AS row_count FROM transactions       WHERE campaign IS NULL
UNION ALL
SELECT 'subscription_plans.duration_days IS NULL', COUNT(*) FROM subscription_plans WHERE duration_days IS NULL
UNION ALL
SELECT 'transactions.amount_usd < 0 (refunds)',   COUNT(*) FROM transactions       WHERE amount_usd < 0
UNION ALL
SELECT 'marketing_spend.country = Global',        COUNT(*) FROM marketing_spend    WHERE country = 'Global';

-- 5.3 Orphan rows: transactions without a matching user or plan (should be 0)
SELECT
  SUM(u.user_id IS NULL) AS tx_without_user,
  SUM(p.plan_id IS NULL) AS tx_without_plan
FROM transactions t
LEFT JOIN users u              ON u.user_id = t.user_id
LEFT JOIN subscription_plans p ON p.plan_id = t.plan_id;
