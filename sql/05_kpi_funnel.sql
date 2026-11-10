USE EcomBehavior;
GO

SELECT
    COUNT(*)                                                      AS events,
    COUNT(DISTINCT user_id)                                       AS users,
    COUNT(DISTINCT user_session)                                  AS sessions,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS buyers,
    SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END)      AS purchases,
    SUM(CASE WHEN event_type = 'purchase' THEN price ELSE 0 END)  AS revenue,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END)
          / COUNT(DISTINCT user_id), 2)                           AS buyer_rate_pct
FROM dbo.fact_events;

SELECT d.full_date,
       d.weekday_name,
       COUNT(DISTINCT f.user_id)                                         AS dau,
       COUNT(*)                                                          AS events,
       COUNT(DISTINCT CASE WHEN f.event_type = 'purchase' THEN f.user_id END) AS buyers,
       SUM(CASE WHEN f.event_type = 'purchase' THEN f.price ELSE 0 END)  AS revenue
FROM dbo.fact_events f
JOIN dbo.dim_date d ON f.date_key = d.date_key
GROUP BY d.full_date, d.weekday_name
ORDER BY d.full_date;

WITH dau AS (
    SELECT date_key, COUNT(DISTINCT user_id) AS dau
    FROM dbo.fact_events
    GROUP BY date_key
),
mau AS (
    SELECT COUNT(DISTINCT user_id) AS mau FROM dbo.fact_events
)
SELECT ROUND(AVG(CAST(dau.dau AS FLOAT)), 0)                       AS avg_dau,
       (SELECT mau FROM mau)                                        AS mau,
       ROUND(100.0 * AVG(CAST(dau.dau AS FLOAT)) / (SELECT mau FROM mau), 2) AS stickiness_pct
FROM dau;

WITH s AS (
    SELECT user_session,
           MAX(CASE WHEN event_type = 'view'     THEN 1 ELSE 0 END) AS has_view,
           MAX(CASE WHEN event_type = 'cart'     THEN 1 ELSE 0 END) AS has_cart,
           MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS has_purchase
    FROM dbo.fact_events
    GROUP BY user_session
)
SELECT
    SUM(has_view)                                                              AS step1_view,
    SUM(CASE WHEN has_view = 1 AND has_cart = 1 THEN 1 ELSE 0 END)             AS step2_cart,
    SUM(CASE WHEN has_view = 1 AND has_cart = 1 AND has_purchase = 1 THEN 1 ELSE 0 END) AS step3_purchase,
    SUM(CASE WHEN has_purchase = 1 AND has_cart = 0 THEN 1 ELSE 0 END)         AS purchase_without_cart,
    ROUND(100.0 * SUM(CASE WHEN has_view = 1 AND has_cart = 1 THEN 1 ELSE 0 END)
          / NULLIF(SUM(has_view), 0), 2)                                       AS view_to_cart_pct,
    ROUND(100.0 * SUM(CASE WHEN has_view = 1 AND has_cart = 1 AND has_purchase = 1 THEN 1 ELSE 0 END)
          / NULLIF(SUM(CASE WHEN has_view = 1 AND has_cart = 1 THEN 1 ELSE 0 END), 0), 2) AS cart_to_purchase_pct,
    ROUND(100.0 * SUM(CASE WHEN has_view = 1 AND has_cart = 1 AND has_purchase = 1 THEN 1 ELSE 0 END)
          / NULLIF(SUM(has_view), 0), 2)                                       AS view_to_purchase_pct
FROM s;

WITH sc AS (
    SELECT f.user_session,
           p.category_main,
           MAX(CASE WHEN f.event_type = 'view'     THEN 1 ELSE 0 END) AS has_view,
           MAX(CASE WHEN f.event_type = 'cart'     THEN 1 ELSE 0 END) AS has_cart,
           MAX(CASE WHEN f.event_type = 'purchase' THEN 1 ELSE 0 END) AS has_purchase
    FROM dbo.fact_events f
    JOIN dbo.dim_product p ON f.product_id = p.product_id
    GROUP BY f.user_session, p.category_main
)
SELECT category_main,
       SUM(has_view)                                                                         AS view_sessions,
       SUM(CASE WHEN has_view = 1 AND has_cart = 1 THEN 1 ELSE 0 END)                        AS cart_sessions,
       SUM(CASE WHEN has_view = 1 AND has_cart = 1 AND has_purchase = 1 THEN 1 ELSE 0 END)   AS purchase_sessions,
       ROUND(100.0 * SUM(CASE WHEN has_view = 1 AND has_cart = 1 THEN 1 ELSE 0 END)
             / NULLIF(SUM(has_view), 0), 2)                                                  AS view_to_cart_pct,
       ROUND(100.0 * SUM(CASE WHEN has_view = 1 AND has_cart = 1 AND has_purchase = 1 THEN 1 ELSE 0 END)
             / NULLIF(SUM(CASE WHEN has_view = 1 AND has_cart = 1 THEN 1 ELSE 0 END), 0), 2) AS cart_to_purchase_pct
FROM sc
GROUP BY category_main
HAVING SUM(has_view) >= 1000         
ORDER BY view_sessions DESC;