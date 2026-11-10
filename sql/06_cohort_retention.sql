USE EcomBehavior;
GO

WITH user_week AS (
    SELECT DISTINCT
           user_id,
           DATEDIFF(DAY, CAST('2019-12-01' AS date), CAST(event_time AS date)) / 7 AS wk
    FROM dbo.fact_events
),
first_wk AS (
    SELECT user_id, MIN(wk) AS cohort_wk
    FROM user_week
    GROUP BY user_id
),
act AS (
    SELECT f.cohort_wk,
           u.wk - f.cohort_wk AS weeks_since,
           COUNT(*)           AS active_users
    FROM first_wk f
    JOIN user_week u ON u.user_id = f.user_id
    WHERE f.cohort_wk <= 3 AND u.wk <= 3
    GROUP BY f.cohort_wk, u.wk - f.cohort_wk
)
SELECT a.cohort_wk,
       DATEADD(DAY, a.cohort_wk * 7, CAST('2019-12-01' AS date)) AS cohort_start,
       a.weeks_since,
       a.active_users,
       s.cohort_size,
       ROUND(100.0 * a.active_users / s.cohort_size, 2)          AS retention_pct
FROM act a
JOIN (SELECT cohort_wk, active_users AS cohort_size
      FROM act WHERE weeks_since = 0) s
  ON s.cohort_wk = a.cohort_wk
ORDER BY a.cohort_wk, a.weeks_since;