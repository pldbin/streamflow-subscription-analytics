-- StreamFlow | extract 01 -> data/users.csv
-- One row per user. Explicit columns and clear names; no business logic here
-- (all metrics are calculated in Power BI with DAX).
SELECT
  user_id,
  signup_date,
  country,
  platform,
  acquisition_channel AS channel,
  age_group
FROM users
ORDER BY user_id;
