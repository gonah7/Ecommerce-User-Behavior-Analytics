USE EcomBehavior;
GO

-- 1. KPI theo ngày, giai đoạn trước / sau ngày 15/12 
CREATE OR ALTER VIEW dbo.vw_daily_kpi AS
SELECT d.full_date,
       d.weekday_name,
       d.is_weekend,
       COUNT(DISTINCT f.user_id)       AS dau,
       COUNT(DISTINCT f.user_session)  AS sessions,
       COUNT(*)                        AS events,
       COUNT(DISTINCT CASE WHEN f.event_type = 'purchase' THEN f.user_id END) AS buyers,
       SUM(CASE WHEN f.event_type = 'purchase' THEN 1 ELSE 0 END)             AS purchases,
       SUM(CASE WHEN f.event_type = 'purchase' THEN f.price ELSE 0 END)       AS revenue,
       CASE WHEN d.full_date <= '2019-12-14' THEN 'Before'
            WHEN d.full_date >= '2019-12-16' THEN 'After'
            ELSE 'Transition' END                                             AS period
FROM dbo.fact_events f
JOIN dbo.dim_date d ON d.date_key = f.date_key
GROUP BY d.full_date, d.weekday_name, d.is_weekend;
GO

-- 2. Funnel theo danh mục
CREATE OR ALTER VIEW dbo.vw_funnel_category AS
WITH sc AS (
    SELECT f.user_session,
           p.category_main,
           MAX(CASE WHEN f.event_type = 'view'     THEN 1 ELSE 0 END) AS has_view,
           MAX(CASE WHEN f.event_type = 'cart'     THEN 1 ELSE 0 END) AS has_cart,
           MAX(CASE WHEN f.event_type = 'purchase' THEN 1 ELSE 0 END) AS has_purchase
    FROM dbo.fact_events f
    JOIN dbo.dim_product p ON p.product_id = f.product_id
    GROUP BY f.user_session, p.category_main
)
SELECT category_main,
       SUM(has_view)                                                                       AS view_sessions,
       SUM(CASE WHEN has_view = 1 AND has_cart = 1 THEN 1 ELSE 0 END)                      AS cart_sessions,
       SUM(CASE WHEN has_view = 1 AND has_cart = 1 AND has_purchase = 1 THEN 1 ELSE 0 END) AS purchase_sessions
FROM sc
GROUP BY category_main;
GO

-- 3. Cohort retention theo tuần 
CREATE OR ALTER VIEW dbo.vw_cohort AS
WITH user_week AS (
    SELECT DISTINCT user_id,
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
       s.cohort_size
FROM act a
JOIN (SELECT cohort_wk, active_users AS cohort_size
      FROM act
      WHERE weeks_since = 0) s
  ON s.cohort_wk = a.cohort_wk;
GO

-- 4. Người dùng mới và quay lại theo ngày 
CREATE OR ALTER VIEW dbo.vw_daily_usertype AS
SELECT d.full_date,
       CASE WHEN CAST(u.first_seen AS date) = d.full_date THEN 'new' ELSE 'returning' END AS user_type,
       COUNT(DISTINCT f.user_id) AS users,
       COUNT(DISTINCT CASE WHEN f.event_type = 'purchase' THEN f.user_id END)   AS buyers,
       SUM(CASE WHEN f.event_type = 'purchase' THEN f.price ELSE 0 END)         AS revenue
FROM dbo.fact_events f
JOIN dbo.dim_date d ON d.date_key = f.date_key
JOIN dbo.dim_user u ON u.user_id  = f.user_id
GROUP BY d.full_date,
         CASE WHEN CAST(u.first_seen AS date) = d.full_date THEN 'new' ELSE 'returning' END;
GO

-- 5. Tổng hợp toàn bộ: tổng người dùng và funnel theo phiên
CREATE OR ALTER VIEW dbo.vw_summary AS
WITH s AS (
    SELECT user_session,
           MAX(CASE WHEN event_type = 'view'     THEN 1 ELSE 0 END) AS has_view,
           MAX(CASE WHEN event_type = 'cart'     THEN 1 ELSE 0 END) AS has_cart,
           MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS has_purchase
    FROM dbo.fact_events
    GROUP BY user_session
)
SELECT (SELECT COUNT(*) FROM dbo.dim_user) AS total_users,
       SUM(has_view) AS view_sessions,
       SUM(CASE WHEN has_view = 1 AND has_cart = 1 THEN 1 ELSE 0 END) AS cart_sessions,
       SUM(CASE WHEN has_view = 1 AND has_cart = 1 AND has_purchase = 1 THEN 1 ELSE 0 END) AS purchase_sessions
FROM s;
GO

/* Kiểm tra: số dòng mỗi view */
SELECT 'vw_daily_kpi'       AS v, COUNT(*) AS n FROM dbo.vw_daily_kpi
UNION ALL SELECT 'vw_funnel_category', COUNT(*) FROM dbo.vw_funnel_category
UNION ALL SELECT 'vw_cohort',          COUNT(*) FROM dbo.vw_cohort
UNION ALL SELECT 'vw_daily_usertype',  COUNT(*) FROM dbo.vw_daily_usertype
UNION ALL SELECT 'vw_summary',         COUNT(*) FROM dbo.vw_summary;
GO

SELECT * FROM dbo.vw_summary;
GO

CREATE OR ALTER VIEW dbo.vw_category_period AS
SELECT p.category_main,
       CASE WHEN d.full_date <= '2019-12-14' THEN 'Before' ELSE 'After' END AS period,
       SUM(f.price) AS revenue
FROM dbo.fact_events f
JOIN dbo.dim_product p ON p.product_id = f.product_id
JOIN dbo.dim_date d    ON d.date_key   = f.date_key
WHERE f.event_type = 'purchase' AND d.full_date <> '2019-12-15'
GROUP BY p.category_main,
         CASE WHEN d.full_date <= '2019-12-14' THEN 'Before' ELSE 'After' END;
GO