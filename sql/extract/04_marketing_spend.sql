-- StreamFlow | extract 04 -> data/marketing_spend.csv
-- Monthly spend by country and channel.
-- month_date: 'YYYY-MM' text turned into a real date (1st of month) for the date table.
-- is_overhead: country = 'Global' rows are shared costs (SMM + Content), not tied to a country.
SELECT
  id                                             AS spend_id,
  STR_TO_DATE(CONCAT(month, '-01'), '%Y-%m-%d')  AS month_date,
  country,
  channel,
  spend_usd,
  CASE WHEN country = 'Global' THEN 1 ELSE 0 END AS is_overhead
FROM marketing_spend
ORDER BY id;
