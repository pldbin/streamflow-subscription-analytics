-- StreamFlow | extract 03 -> data/subscription_plans.csv
-- Plan catalogue. duration_days is NULL for Lifetime (no expiry).
SELECT
  plan_id,
  plan_name,
  duration_days,
  list_price_usd
FROM subscription_plans
ORDER BY plan_id;
