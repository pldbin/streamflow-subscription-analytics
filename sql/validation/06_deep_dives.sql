-- =============================================================================
-- StreamFlow | validation 06 — deep dives (advanced questions)
-- Purpose : rebuild the "Deep Dives" page in SQL:
--           Black Friday cohort, Facebook Ads cost spike, Brazil pricing.
-- =============================================================================

-- 6.1 Black Friday cohort (Nov 2024) vs neighbouring cohorts
-- Power BI: 2024-10  311 users, 71.1%, annual 17.8%, $51.93, LTV $83.45, M1 47.6%, M6 44.4%
--           2024-11  436 users, 72.7%, annual 50.4%, $30.76, LTV $56.64, M1 34.2%, M6 25.9%
--           2024-12  311 users, 70.7%, annual 24.9%, $37.54, LTV $64.23, M1 43.7%, M6 39.9%
--           2025-01  389 users, 70.4%, annual 17.0%, $51.40, LTV $64.72, M1 46.5%, M6 41.4%
WITH
cohort_users AS (
  SELECT user_id, DATE_FORMAT(signup_date, '%Y-%m') AS cohort_month, signup_date
  FROM users
  WHERE signup_date >= '2024-10-01' AND signup_date < '2025-02-01'
),
txn AS (
  SELECT
    c.cohort_month,
    t.user_id,
    t.transaction_type,
    t.amount_usd,
    p.plan_name,
    PERIOD_DIFF(DATE_FORMAT(t.date, '%Y%m'), DATE_FORMAT(c.signup_date, '%Y%m')) AS month_offset
  FROM transactions t
  JOIN cohort_users c       ON c.user_id = t.user_id
  JOIN subscription_plans p ON p.plan_id = t.plan_id
),
cohort_size AS (
  SELECT cohort_month, COUNT(*) AS users FROM cohort_users GROUP BY cohort_month
)
SELECT
  s.cohort_month,
  s.users,
  ROUND(100 * COUNT(DISTINCT CASE WHEN x.transaction_type = 'first_payment' THEN x.user_id END) / s.users, 1) AS signup_to_paid_pct,
  ROUND(100 * SUM(x.transaction_type = 'first_payment' AND x.plan_name = 'Annual')
            / SUM(x.transaction_type = 'first_payment'), 1)                                                   AS annual_share_pct,
  ROUND(AVG(CASE WHEN x.transaction_type = 'first_payment' AND x.plan_name = 'Annual' THEN x.amount_usd END), 2) AS avg_annual_price,
  ROUND(SUM(x.amount_usd) / s.users, 2)                                                                        AS ltv_per_user,
  ROUND(100 * COUNT(DISTINCT CASE WHEN x.month_offset = 1
                                   AND x.transaction_type IN ('first_payment', 'renewal', 'upgrade')
                                  THEN x.user_id END) / s.users, 1)                                            AS retention_m1_pct,
  ROUND(100 * COUNT(DISTINCT CASE WHEN x.month_offset = 6
                                   AND x.transaction_type IN ('first_payment', 'renewal', 'upgrade')
                                  THEN x.user_id END) / s.users, 1)                                            AS retention_m6_pct
FROM cohort_size s
JOIN txn x ON x.cohort_month = s.cohort_month
GROUP BY s.cohort_month, s.users
ORDER BY s.cohort_month;


-- 6.2 CAC per new user by month and paid channel (spend in the month / users who signed up that month)
-- Power BI line chart: Facebook Ads jumps in Jun 2024 (~$65.6) while other channels stay flat
WITH
spend AS (
  SELECT month, channel, SUM(spend_usd) AS spend_usd
  FROM marketing_spend
  WHERE country <> 'Global'
  GROUP BY month, channel
),
new_users AS (
  SELECT DATE_FORMAT(signup_date, '%Y-%m') AS month, acquisition_channel AS channel, COUNT(*) AS users
  FROM users
  GROUP BY DATE_FORMAT(signup_date, '%Y-%m'), acquisition_channel
),
cac AS (
  SELECT s.month, s.channel, s.spend_usd / n.users AS cac
  FROM spend s
  JOIN new_users n ON n.month = s.month AND n.channel = s.channel
)
SELECT
  month,
  ROUND(MAX(CASE WHEN channel = 'Facebook Ads'     THEN cac END), 2) AS facebook_ads,
  ROUND(MAX(CASE WHEN channel = 'Google Ads'       THEN cac END), 2) AS google_ads,
  ROUND(MAX(CASE WHEN channel = 'Apple Search Ads' THEN cac END), 2) AS apple_search_ads,
  ROUND(MAX(CASE WHEN channel = 'TikTok Ads'       THEN cac END), 2) AS tiktok_ads,
  ROUND(MAX(CASE WHEN channel = 'Influencer'       THEN cac END), 2) AS influencer
FROM cac
GROUP BY month
ORDER BY month;


-- 6.3 Facebook Ads CAC before and during the spike (quarter vs quarter)
-- Power BI / report: Feb-Apr 2024 $36.7 -> May-Jul 2024 $54.7
WITH
fb_spend AS (
  SELECT month, SUM(spend_usd) AS spend_usd
  FROM marketing_spend
  WHERE channel = 'Facebook Ads' AND country <> 'Global'
  GROUP BY month
),
fb_users AS (
  SELECT DATE_FORMAT(signup_date, '%Y-%m') AS month, COUNT(*) AS users
  FROM users
  WHERE acquisition_channel = 'Facebook Ads'
  GROUP BY DATE_FORMAT(signup_date, '%Y-%m')
)
SELECT
  CASE WHEN s.month BETWEEN '2024-02' AND '2024-04' THEN '1) Feb-Apr 2024'
       ELSE '2) May-Jul 2024' END              AS period,
  SUM(s.spend_usd)                            AS spend_usd,
  SUM(u.users)                                AS new_users,
  ROUND(SUM(s.spend_usd) / SUM(u.users), 1)   AS cac
FROM fb_spend s
JOIN fb_users u ON u.month = s.month
WHERE s.month BETWEEN '2024-02' AND '2024-07'
GROUP BY period
ORDER BY period;


-- 6.4 Average price actually paid for the Monthly plan (list price $14.99), by country
-- Power BI: UK $14.99 · US $14.99 · DE $14.24 · PL $11.99 · MX $11.24 · BR $10.79
SELECT
  u.country,
  COUNT(*)                   AS monthly_payments,
  ROUND(AVG(t.amount_usd), 2) AS avg_price_paid
FROM transactions t
JOIN users u              ON u.user_id = t.user_id
JOIN subscription_plans p ON p.plan_id = t.plan_id
WHERE p.plan_name = 'Monthly'
  AND t.transaction_type IN ('first_payment', 'renewal')
GROUP BY u.country
ORDER BY avg_price_paid DESC;
