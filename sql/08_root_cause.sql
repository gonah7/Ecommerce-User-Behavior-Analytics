USE EcomBehavior;
GO

-- Doanh thu
WITH daily AS (
    SELECT d.full_date,
           CASE WHEN d.full_date <= CAST('2019-12-14' AS date) THEN 'A_before'
                WHEN d.full_date >= CAST('2019-12-16' AS date) THEN 'B_after' END AS period,
           COUNT(DISTINCT f.user_id)       AS dau,
           COUNT(DISTINCT f.user_session)  AS sessions,
           COUNT(DISTINCT CASE WHEN f.event_type = 'purchase' THEN f.user_id END) AS buyers,
           SUM(CASE WHEN f.event_type = 'purchase' THEN 1 ELSE 0 END)             AS purchases,
           SUM(CASE WHEN f.event_type = 'purchase' THEN f.price ELSE 0 END)       AS revenue
    FROM dbo.fact_events f
    JOIN dbo.dim_date d ON d.date_key = f.date_key
    GROUP BY d.full_date
)
SELECT period,
       COUNT(*)                                            AS days,
       ROUND(AVG(1.0 * dau), 0)                            AS avg_dau,
       ROUND(AVG(1.0 * sessions), 0)                       AS avg_sessions,
       ROUND(AVG(1.0 * buyers), 0)                         AS avg_buyers,
       ROUND(AVG(revenue), 0)                              AS avg_revenue,
       ROUND(100.0 * SUM(buyers) / SUM(dau), 2)            AS buyers_per_dau_pct,
       ROUND(1.0 * SUM(purchases) / SUM(buyers), 2)        AS purchases_per_buyer,
       ROUND(SUM(revenue) / SUM(purchases), 2)             AS revenue_per_purchase
FROM daily
WHERE period IS NOT NULL
GROUP BY period
ORDER BY period;
GO


-- User mới và user quay lại theo ngày
SELECT d.full_date,
       COUNT(DISTINCT f.user_id) AS dau,
       COUNT(DISTINCT CASE WHEN CAST(u.first_seen AS date) = d.full_date THEN f.user_id END) AS new_users
FROM dbo.fact_events f
JOIN dbo.dim_user u ON u.user_id = f.user_id
JOIN dbo.dim_date d ON d.date_key = f.date_key
GROUP BY d.full_date
ORDER BY d.full_date;
GO


-- Danh mục đóng góp vào doanh thu
WITH x AS (
    SELECT p.category_main,
           f.price,
           CASE WHEN d.full_date <= CAST('2019-12-14' AS date) THEN 'before'
                WHEN d.full_date >= CAST('2019-12-16' AS date) THEN 'after' END AS period
    FROM dbo.fact_events f
    JOIN dbo.dim_product p ON p.product_id = f.product_id
    JOIN dbo.dim_date d    ON d.date_key   = f.date_key
    WHERE f.event_type = 'purchase'
),
agg AS (
    SELECT category_main,
           SUM(CASE WHEN period = 'before' THEN price ELSE 0 END) / 14.0 AS rev_per_day_before,
           SUM(CASE WHEN period = 'after'  THEN price ELSE 0 END) / 16.0 AS rev_per_day_after
    FROM x
    GROUP BY category_main
)
SELECT category_main,
       ROUND(rev_per_day_before, 0)                              AS before_per_day,
       ROUND(rev_per_day_after, 0)                               AS after_per_day,
       ROUND(rev_per_day_after - rev_per_day_before, 0)          AS change_per_day,
       ROUND(100.0 * (rev_per_day_after - rev_per_day_before)
             / SUM(rev_per_day_after - rev_per_day_before) OVER (), 2) AS pct_of_total_change,
       ROUND(100.0 * (rev_per_day_after / NULLIF(rev_per_day_before, 0) - 1), 1) AS growth_pct
FROM agg
ORDER BY change_per_day DESC;
GO


-- Tỷ lệ mua của user mới và user quay lại, trước và sau
WITH ud AS (
    SELECT f.user_id, d.full_date,
           MAX(CASE WHEN f.event_type = 'purchase' THEN 1 ELSE 0 END)           AS bought,
           SUM(CASE WHEN f.event_type = 'purchase' THEN f.price ELSE 0 END)     AS revenue
    FROM dbo.fact_events f
    JOIN dbo.dim_date d ON d.date_key = f.date_key
    GROUP BY f.user_id, d.full_date
),
x AS (
    SELECT ud.*,
           CASE WHEN CAST(u.first_seen AS date) = ud.full_date THEN 'new' ELSE 'returning' END AS user_type,
           CASE WHEN ud.full_date BETWEEN '2019-12-08' AND '2019-12-14' THEN 'A_before'
                WHEN ud.full_date >= '2019-12-16'                       THEN 'B_after' END    AS period
    FROM ud
    JOIN dbo.dim_user u ON u.user_id = ud.user_id
)
SELECT period, user_type,
       COUNT(*)                                       AS user_days,
       ROUND(100.0 * SUM(bought) / COUNT(*), 2)       AS buyer_rate_pct,
       ROUND(SUM(revenue) / COUNT(DISTINCT full_date), 0) AS revenue_per_day
FROM x
WHERE period IS NOT NULL
GROUP BY period, user_type
ORDER BY period, user_type;
GO

-- Kiểm tra sự ổn định, loại 10 người chi nhiều nhất
WITH top_users AS (
    SELECT TOP 10 user_id FROM dbo.user_rfm ORDER BY monetary DESC
),
x AS (
    SELECT d.full_date, f.price,
           CASE WHEN d.full_date <= CAST('2019-12-14' AS date) THEN 'A_before'
                WHEN d.full_date >= CAST('2019-12-16' AS date) THEN 'B_after' END AS period
    FROM dbo.fact_events f
    JOIN dbo.dim_date d ON d.date_key = f.date_key
    WHERE f.event_type = 'purchase'
      AND f.user_id NOT IN (SELECT user_id FROM top_users)
)
SELECT period,
       ROUND(SUM(price) / COUNT(DISTINCT full_date), 0) AS avg_revenue_per_day
FROM x
WHERE period IS NOT NULL
GROUP BY period
ORDER BY period;
GO