-- StreamFlow | extract 02 -> data/transactions.csv
-- One row per transaction (trial_start, first_payment, renewal, upgrade, refund).
-- txn_date = calendar date without time, used to join the Power BI date table.
SELECT
  transaction_id,
  user_id,
  plan_id,
  date       AS txn_datetime,
  DATE(date) AS txn_date,
  transaction_type,
  amount_usd,
  campaign
FROM transactions
ORDER BY transaction_id;
