-- =============================================================================
-- StreamFlow | validation 05 — campaigns, win-back and refunds
-- Purpose : rebuild the "Refunds & Campaigns" page in SQL.
--           campaign IS NULL means the transaction is not linked to any campaign
--           (shown as 'None' in Power BI).
-- =============================================================================

-- 5.1 Campaigns: renewals, upgrades and revenue
-- Power BI: Email 1,170 renewals (7.9%), 232 upgrades (43.4%), $33,593
--           Push Notification 750 (5.1%), 139 (26.0%), $21,083
--           Win-back 308 renewals, $8,631 · Discount $5,538 · Total 14,744 / 535 / $343,563
SELECT
  COALESCE(campaign, 'None')                                                      AS campaign,
  SUM(transaction_type = 'renewal')                                               AS renewals,
  ROUND(100 * SUM(transaction_type = 'renewal') / SUM(SUM(transaction_type = 'renewal')) OVER (), 1) AS share_of_renewals_pct,
  SUM(transaction_type = 'upgrade')                                               AS upgrades,
  ROUND(100 * SUM(transaction_type = 'upgrade') / SUM(SUM(transaction_type = 'upgrade')) OVER (), 1) AS share_of_upgrades_pct,
  ROUND(SUM(amount_usd), 2)                                                       AS net_revenue,
  ROUND(100 * SUM(amount_usd) / SUM(SUM(amount_usd)) OVER (), 1)                  AS share_of_revenue_pct
FROM transactions
GROUP BY COALESCE(campaign, 'None')
ORDER BY net_revenue DESC;


-- 5.2 Win-back: users who came back through the campaign and renewed afterwards
-- Power BI: 223 returned users, 160 renewed after returning = 71.7%
WITH
returned AS (
  SELECT user_id, MIN(date) AS return_date
  FROM transactions
  WHERE campaign = 'Win-back'
    AND transaction_type = 'first_payment'
  GROUP BY user_id
)
SELECT
  COUNT(DISTINCT r.user_id)                                              AS returned_users,
  COUNT(DISTINCT t.user_id)                                              AS renewed_after,
  ROUND(100 * COUNT(DISTINCT t.user_id) / COUNT(DISTINCT r.user_id), 1)  AS renewal_rate_pct
FROM returned r
LEFT JOIN transactions t
  ON  t.user_id = r.user_id
  AND t.transaction_type = 'renewal'
  AND t.date > r.return_date;      -- any renewal after the win-back payment, with or without a campaign


-- 5.3 Refund rate by country (refunds / gross revenue)
-- Power BI: MX 1.04% · BR 0.82% · US 0.54% · DE 0.42% · UK 0.28% · PL 0.11%
SELECT
  u.country,
  ROUND(-SUM(CASE WHEN t.transaction_type = 'refund' THEN t.amount_usd ELSE 0 END), 2) AS refunds,
  ROUND(SUM(CASE WHEN t.amount_usd > 0 THEN t.amount_usd ELSE 0 END), 2)               AS gross_revenue,
  ROUND(100 * -SUM(CASE WHEN t.transaction_type = 'refund' THEN t.amount_usd ELSE 0 END)
        / SUM(CASE WHEN t.amount_usd > 0 THEN t.amount_usd ELSE 0 END), 2)             AS refund_rate_pct
FROM transactions t
JOIN users u ON u.user_id = t.user_id
GROUP BY u.country
ORDER BY refund_rate_pct DESC;


-- 5.4 Refunded amount by month
-- Power BI: peak 2025-03 = $268.55, 2025-01 = $224.03
SELECT
  DATE_FORMAT(date, '%Y-%m')  AS month,
  COUNT(*)                    AS refunds,
  ROUND(-SUM(amount_usd), 2)  AS refunded_usd
FROM transactions
WHERE transaction_type = 'refund'
GROUP BY DATE_FORMAT(date, '%Y-%m')
ORDER BY month;
