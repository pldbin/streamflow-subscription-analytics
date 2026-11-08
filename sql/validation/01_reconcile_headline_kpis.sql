-- =============================================================================
-- StreamFlow | validation 01 — headline KPIs: SQL vs Power BI
-- Purpose : recompute every headline number of the dashboard directly in SQL
--           and compare it with the value the DAX measure shows in Power BI.
--           status = 'OK' means SQL and DAX agree at the precision shown in the report.
-- Source  : MySQL database `streamflow` (raw tables, not the CSV extracts).
-- Rounding: money to 2 decimals, percentages to 1 decimal (2 for Refund Rate),
--           ratios to 2 decimals — the same precision as the Power BI visuals.
-- =============================================================================

WITH
user_flags AS (
  -- one row per user who has any transaction: did they start a trial / make a first payment?
  -- (= dim_users[HasTrial] / dim_users[HasPaid] in Power BI)
  SELECT
    user_id,
    MAX(transaction_type = 'trial_start')   AS has_trial,
    MAX(transaction_type = 'first_payment') AS has_paid
  FROM transactions
  GROUP BY user_id
),
base AS (
  SELECT
    (SELECT COUNT(*) FROM users)                                                    AS total_users,
    (SELECT COUNT(*) FROM transactions)                                             AS txn_count,
    (SELECT SUM(amount_usd) FROM transactions)                                      AS net_revenue,
    (SELECT SUM(amount_usd) FROM transactions WHERE amount_usd > 0)                 AS gross_revenue,
    (SELECT -SUM(amount_usd) FROM transactions WHERE transaction_type = 'refund')   AS refunds,
    (SELECT COUNT(*) FROM transactions WHERE transaction_type = 'refund')           AS refund_count,
    (SELECT COUNT(DISTINCT user_id) FROM transactions WHERE transaction_type = 'refund')  AS refund_users,
    (SELECT SUM(spend_usd) FROM marketing_spend)                                    AS total_spend,
    (SELECT SUM(spend_usd) FROM marketing_spend WHERE country <> 'Global')          AS direct_spend,
    (SELECT SUM(spend_usd) FROM marketing_spend WHERE country = 'Global')           AS overhead,
    (SELECT SUM(has_trial) FROM user_flags)                                         AS trial_users,
    (SELECT SUM(has_paid)  FROM user_flags)                                         AS paying_users,
    (SELECT SUM(has_trial = 1 AND has_paid = 1) FROM user_flags)                    AS paid_with_trial,
    (SELECT SUM(has_trial = 0 AND has_paid = 1) FROM user_flags)                    AS paid_without_trial,
    (SELECT COUNT(DISTINCT user_id) FROM transactions WHERE transaction_type = 'renewal') AS renewed_users,
    (SELECT COUNT(DISTINCT user_id) FROM transactions WHERE transaction_type = 'upgrade') AS upgraded_users
),
sql_values AS (
  SELECT 1 AS sort_order, 'Total Users' AS metric, total_users AS sql_value FROM base
  UNION ALL SELECT  2, 'Transactions',            txn_count                                        FROM base
  UNION ALL SELECT  3, 'Net Revenue, $',          ROUND(net_revenue, 2)                            FROM base
  UNION ALL SELECT  4, 'Gross Revenue, $',        ROUND(gross_revenue, 2)                          FROM base
  UNION ALL SELECT  5, 'Refunds, $',              ROUND(refunds, 2)                                FROM base
  UNION ALL SELECT  6, 'Refund Count',            refund_count                                     FROM base
  UNION ALL SELECT  7, 'Refund Users',            refund_users                                     FROM base
  UNION ALL SELECT  8, 'Refund Rate %',           ROUND(100 * refunds / gross_revenue, 2)          FROM base
  UNION ALL SELECT  9, 'Total Spend, $',          total_spend                                      FROM base
  UNION ALL SELECT 10, 'Direct Spend, $',         direct_spend                                     FROM base
  UNION ALL SELECT 11, 'Overhead (Global), $',    overhead                                         FROM base
  UNION ALL SELECT 12, 'Trial Users',             trial_users                                      FROM base
  UNION ALL SELECT 13, 'Paying Users',            paying_users                                     FROM base
  UNION ALL SELECT 14, 'Paid with Trial',         paid_with_trial                                  FROM base
  UNION ALL SELECT 15, 'Paid without Trial',      paid_without_trial                               FROM base
  UNION ALL SELECT 16, 'Renewed Users',           renewed_users                                    FROM base
  UNION ALL SELECT 17, 'Upgraded Users',          upgraded_users                                   FROM base
  UNION ALL SELECT 18, 'Trial to Paid %',         ROUND(100 * paid_with_trial / trial_users, 1)    FROM base
  UNION ALL SELECT 19, 'Signup to Paid %',        ROUND(100 * paying_users / total_users, 1)       FROM base
  UNION ALL SELECT 20, 'Renewal Rate %',          ROUND(100 * renewed_users / paying_users, 1)     FROM base
  UNION ALL SELECT 21, 'LTV per User, $',         ROUND(net_revenue / total_users, 2)              FROM base
  UNION ALL SELECT 22, 'ARPPU, $',                ROUND(net_revenue / paying_users, 2)             FROM base
  UNION ALL SELECT 23, 'CAC Direct, $',           ROUND(direct_spend / total_users, 2)             FROM base
  UNION ALL SELECT 24, 'CAC Loaded, $',           ROUND(total_spend / total_users, 2)              FROM base
  UNION ALL SELECT 25, 'LTV to CAC Direct',       ROUND(net_revenue / direct_spend, 1)             FROM base
  UNION ALL SELECT 26, 'ROAS',                    ROUND(net_revenue / total_spend, 2)              FROM base
),
power_bi_values AS (
  -- values as shown in the Power BI report (cards, tables, totals)
  SELECT 'Total Users' AS metric, 5000 AS power_bi_value
  UNION ALL SELECT 'Transactions',          23020
  UNION ALL SELECT 'Net Revenue, $',        343563.00
  UNION ALL SELECT 'Gross Revenue, $',      345340.03
  UNION ALL SELECT 'Refunds, $',            1777.03
  UNION ALL SELECT 'Refund Count',          77
  UNION ALL SELECT 'Refund Users',          76
  UNION ALL SELECT 'Refund Rate %',         0.51
  UNION ALL SELECT 'Total Spend, $',        184530
  UNION ALL SELECT 'Direct Spend, $',       91780
  UNION ALL SELECT 'Overhead (Global), $',  92750
  UNION ALL SELECT 'Trial Users',           3831
  UNION ALL SELECT 'Paying Users',          3602
  UNION ALL SELECT 'Paid with Trial',       2452
  UNION ALL SELECT 'Paid without Trial',    1150
  UNION ALL SELECT 'Renewed Users',         2495
  UNION ALL SELECT 'Upgraded Users',        535
  UNION ALL SELECT 'Trial to Paid %',       64.0
  UNION ALL SELECT 'Signup to Paid %',      72.0
  UNION ALL SELECT 'Renewal Rate %',        69.3
  UNION ALL SELECT 'LTV per User, $',       68.71
  UNION ALL SELECT 'ARPPU, $',              95.38
  UNION ALL SELECT 'CAC Direct, $',         18.36
  UNION ALL SELECT 'CAC Loaded, $',         36.91
  UNION ALL SELECT 'LTV to CAC Direct',     3.7
  UNION ALL SELECT 'ROAS',                  1.86
)
SELECT
  s.metric,
  s.sql_value,
  p.power_bi_value,
  CASE WHEN s.sql_value = p.power_bi_value THEN 'OK' ELSE 'CHECK' END AS status
FROM sql_values s
JOIN power_bi_values p ON p.metric = s.metric
ORDER BY s.sort_order;
