USE EcomBehavior;
GO

IF OBJECT_ID('dbo.user_rfm') IS NOT NULL DROP TABLE dbo.user_rfm;
GO

WITH base AS (
    SELECT user_id,
           DATEDIFF(DAY, MAX(CAST(event_time AS date)), CAST('2020-01-01' AS date)) AS recency_days,
           COUNT(DISTINCT user_session) AS frequency,     -- số phiên có mua (xấp xỉ số đơn)
           COUNT(*)                     AS items_bought,  -- số lượt purchase
           SUM(price)                   AS monetary
    FROM dbo.fact_events
    WHERE event_type = 'purchase'
    GROUP BY user_id
),
scored AS (
    SELECT *,
           CASE WHEN recency_days <= 7  THEN 5
                WHEN recency_days <= 14 THEN 4
                WHEN recency_days <= 21 THEN 3
                WHEN recency_days <= 28 THEN 2
                ELSE 1 END                        AS r_score,
           NTILE(5) OVER (ORDER BY monetary ASC)  AS m_score
    FROM base
)
SELECT *,
       -- mức gần đây (R) x số lần mua (F), các nhóm loại trừ nhau
       CASE WHEN r_score >= 4 AND frequency >= 3 THEN 'Champions'
            WHEN r_score = 3  AND frequency >= 3 THEN 'Loyal'
            WHEN r_score <= 2 AND frequency >= 3 THEN 'At risk'
            WHEN r_score >= 4                    THEN 'Recent buyers'
            WHEN r_score = 3                     THEN 'Need attention'
            ELSE 'Hibernating' END                AS segment
INTO dbo.user_rfm
FROM scored;
GO

-- 1. Phân bố tần số
SELECT frequency, COUNT(*) AS buyers
FROM dbo.user_rfm
GROUP BY frequency
ORDER BY frequency;
GO

-- 2. Tóm tắt
SELECT segment,
       COUNT(*)                                                      AS users,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)            AS pct_users,
       ROUND(SUM(monetary), 0)                                       AS revenue,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 2)  AS pct_revenue,
       ROUND(AVG(1.0 * recency_days), 1)                             AS avg_recency_days,
       ROUND(AVG(1.0 * frequency), 2)                                AS avg_frequency,
       ROUND(AVG(monetary), 2)                                       AS avg_monetary
FROM dbo.user_rfm
GROUP BY segment
ORDER BY revenue DESC;
GO

-- 3. Doanh thu có tập trung như thế nào?
SELECT
  ROUND(100.0 * SUM(CASE WHEN rk <= CEILING(0.01 * n) THEN monetary ELSE 0 END) / SUM(monetary), 2) AS top_1pct_share,
  ROUND(100.0 * SUM(CASE WHEN rk <= CEILING(0.10 * n) THEN monetary ELSE 0 END) / SUM(monetary), 2) AS top_10pct_share
FROM (
    SELECT monetary,
           ROW_NUMBER() OVER (ORDER BY monetary DESC) AS rk,
           COUNT(*) OVER ()                           AS n
    FROM dbo.user_rfm
) t;
GO

-- 4. 10 người chi nhiều nhất
SELECT TOP 10 user_id, frequency, items_bought, monetary
FROM dbo.user_rfm
ORDER BY monetary DESC;
GO