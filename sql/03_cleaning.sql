USE EcomBehavior;
GO

-- Xóa bảng cũ nếu tồn tại 
IF OBJECT_ID('dbo.events_clean') IS NOT NULL DROP TABLE dbo.events_clean;
GO

WITH parsed AS (
    SELECT
        TRY_CONVERT(datetime2(0), LEFT(event_time, 19))     AS event_time,  
        event_type,
        product_id,
        category_id,
        NULLIF(LTRIM(RTRIM(category_code)), '')             AS category_code, -- giữ NULL khi thiếu
        ISNULL(NULLIF(LTRIM(RTRIM(brand)), ''), 'unknown')  AS brand,         -- thiếu ghi 'unknown'
        price,
        user_id,
        user_session
    FROM dbo.raw_events
),
filtered AS (
    SELECT *
    FROM parsed
    WHERE event_time IS NOT NULL
      AND user_id    IS NOT NULL
      AND product_id IS NOT NULL
      AND price      IS NOT NULL
      AND price      > 0      -- bỏ giá <= 0
      AND event_type IN ('view', 'cart', 'remove_from_cart', 'purchase')
),
dedup AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY event_time, event_type, product_id, user_id, user_session
               ORDER BY (SELECT NULL)) AS rn
    FROM filtered
)
SELECT event_time, event_type, product_id, category_id,
       category_code, brand, price, user_id, user_session
INTO dbo.events_clean
FROM dedup
WHERE rn = 1;   -- giữ 1 dòng trong mỗi nhóm trùng
GO

-- Số dòng trước và sau khi làm sạch
SELECT
    (SELECT COUNT(*) FROM dbo.raw_events)   AS rows_before,
    (SELECT COUNT(*) FROM dbo.events_clean) AS rows_after,
    (SELECT COUNT(*) FROM dbo.raw_events)
      - (SELECT COUNT(*) FROM dbo.events_clean) AS rows_removed;
GO