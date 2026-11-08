-- =============================================================================
-- StreamFlow | validation 04 — unit economics by country and by channel
-- Purpose : rebuild the "Unit Economics" page tables in SQL.
-- Definitions (same as the DAX model):
--   LTV per user  = net revenue of the users / number of users
--   CAC direct    = country (or channel) spend / number of users
--   CAC loaded    = (direct spend + Global overhead split by the country's share of users) / users
--   contribution  = net revenue - direct spend
-- Note    : joins go from transactions to users (users.user_id is the primary key),
--           so the queries stay fast even without an index on transactions.user_id.
-- =============================================================================

-- 4.1 By country
-- Power BI: BR LTV $40.44, CAC $5.61 / $24.16, LTV/CAC 7.2x / 1.67x
--           US LTV $96.31, CAC $26.63 / $45.18, LTV/CAC 3.6x / 2.13x
--           Total LTV $68.71, CAC $18.36 / $36.91
WITH
users_by_country AS (
  SELECT country, COUNT(*) AS users
  FROM users
  GROUP BY country
),
revenue_by_country AS (
  SELECT u.country, SUM(t.amount_usd) AS net_revenue
  FROM transactions t
  JOIN users u ON u.user_id = t.user_id
  GROUP BY u.country
),
spend_by_country AS (
  SELECT country, SUM(spend_usd) AS direct_spend
  FROM marketing_spend
  WHERE country <> 'Global'
  GROUP BY country
),
overhead AS (
  SELECT SUM(spend_usd) AS overhead FROM marketing_spend WHERE country = 'Global'
),
total_users AS (
  SELECT COUNT(*) AS users FROM users
)
SELECT
  uc.country,
  uc.users,
  ROUND(r.net_revenue / uc.users, 2)                                         AS ltv_per_user,
  ROUND(s.direct_spend / uc.users, 2)                                        AS cac_direct,
  ROUND((s.direct_spend + o.overhead * uc.users / tu.users) / uc.users, 2)   AS cac_loaded,
  ROUND(r.net_revenue / s.direct_spend, 1)                                   AS ltv_to_cac_direct,
  ROUND(r.net_revenue / (s.direct_spend + o.overhead * uc.users / tu.users), 2) AS ltv_to_cac_loaded
FROM users_by_country uc
JOIN revenue_by_country r ON r.country = uc.country
JOIN spend_by_country   s ON s.country = uc.country
CROSS JOIN overhead o
CROSS JOIN total_users tu
ORDER BY ltv_to_cac_direct DESC;


-- 4.2 By acquisition channel
-- Power BI: Google Ads 1,128 users, Trial->Paid 64.8%, Renewal 75.2%, LTV $80.00,
--           CAC $28.64, CAC/payer $39.21, LTV/CAC 2.8x, contribution $57,934 (23.0%)
--           Total contribution $251,783
WITH
user_flags AS (
  SELECT
    user_id,
    MAX(transaction_type = 'trial_start')   AS has_trial,
    MAX(transaction_type = 'first_payment') AS has_paid,
    MAX(transaction_type = 'renewal')       AS has_renewal,
    SUM(amount_usd)                         AS net_revenue
  FROM transactions
  GROUP BY user_id
),
by_channel AS (
  SELECT
    u.acquisition_channel                    AS channel,
    COUNT(*)                                 AS users,
    SUM(f.has_trial)                         AS trial_users,
    SUM(f.has_trial = 1 AND f.has_paid = 1)  AS paid_with_trial,
    SUM(f.has_paid)                          AS paying_users,
    SUM(f.has_renewal)                       AS renewed_users,
    SUM(f.net_revenue)                       AS net_revenue
  FROM users u
  LEFT JOIN user_flags f ON f.user_id = u.user_id
  GROUP BY u.acquisition_channel
),
spend_by_channel AS (
  SELECT channel, SUM(spend_usd) AS direct_spend
  FROM marketing_spend
  WHERE country <> 'Global'
  GROUP BY channel
)
SELECT
  b.channel,
  b.users,
  ROUND(100 * b.paid_with_trial / b.trial_users, 1)       AS trial_to_paid_pct,
  ROUND(100 * b.renewed_users / b.paying_users, 1)        AS renewal_rate_pct,
  ROUND(b.net_revenue / b.users, 2)                       AS ltv_per_user,
  ROUND(s.direct_spend / b.users, 2)                      AS cac_direct,
  ROUND(s.direct_spend / b.paying_users, 2)               AS cac_per_payer,
  ROUND(b.net_revenue / s.direct_spend, 1)                AS ltv_to_cac_direct,
  ROUND(b.net_revenue - COALESCE(s.direct_spend, 0), 0)   AS contribution,
  ROUND(100 * (b.net_revenue - COALESCE(s.direct_spend, 0))
        / SUM(b.net_revenue - COALESCE(s.direct_spend, 0)) OVER (), 1) AS contribution_share_pct
FROM by_channel b
LEFT JOIN spend_by_channel s ON s.channel = b.channel
ORDER BY ltv_per_user DESC;
