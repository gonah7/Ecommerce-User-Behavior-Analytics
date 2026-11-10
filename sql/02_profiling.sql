USE EcomBehavior;
GO

-- 1. Tổng quát
SELECT COUNT(*)                     AS total_rows,
       COUNT(DISTINCT user_id)      AS users,
       COUNT(DISTINCT user_session) AS sessions,
       COUNT(DISTINCT product_id)   AS products
FROM dbo.raw_events;

-- 2. Khoảng thời gian dữ liệu
SELECT MIN(LEFT(event_time,19)) AS min_time,
       MAX(LEFT(event_time,19)) AS max_time
FROM dbo.raw_events;

-- 3. Giá trị thiếu và bất thường
SELECT
  SUM(CASE WHEN event_time    IS NULL THEN 1 ELSE 0 END) AS null_time,
  SUM(CASE WHEN user_id       IS NULL THEN 1 ELSE 0 END) AS null_user,
  SUM(CASE WHEN user_session  IS NULL THEN 1 ELSE 0 END) AS null_session,
  SUM(CASE WHEN product_id    IS NULL THEN 1 ELSE 0 END) AS null_product,
  SUM(CASE WHEN price         IS NULL THEN 1 ELSE 0 END) AS null_price,
  SUM(CASE WHEN price <= 0             THEN 1 ELSE 0 END) AS price_le_0,
  SUM(CASE WHEN brand         IS NULL THEN 1 ELSE 0 END) AS null_brand,
  SUM(CASE WHEN category_code IS NULL THEN 1 ELSE 0 END) AS null_category_code
FROM dbo.raw_events;

-- 4. Phân bố loại sự kiện
SELECT event_type, COUNT(*) AS n
FROM dbo.raw_events
GROUP BY event_type
ORDER BY n DESC;

-- 5. Số dòng trùng lặp
SELECT COUNT(*) AS duplicate_rows
FROM (
  SELECT ROW_NUMBER() OVER (
           PARTITION BY event_time, event_type, product_id, user_id, user_session
           ORDER BY (SELECT NULL)) AS rn
  FROM dbo.raw_events
) t
WHERE rn > 1;


-- Dòng giá <= 0 thuộc loại sự kiện nào?
SELECT event_type, COUNT(*) AS n
FROM dbo.raw_events
WHERE price <= 0
GROUP BY event_type;

-- Dòng trùng lặp thuộc loại sự kiện nào?
SELECT event_type, COUNT(*) AS n
FROM (
    SELECT event_type,
           ROW_NUMBER() OVER (
               PARTITION BY event_time, event_type, product_id, user_id, user_session
               ORDER BY (SELECT NULL)) AS rn
    FROM dbo.raw_events
) t
WHERE rn > 1
GROUP BY event_type;