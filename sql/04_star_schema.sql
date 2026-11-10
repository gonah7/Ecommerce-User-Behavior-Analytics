USE EcomBehavior;
GO

-- DIM_USER
IF OBJECT_ID('dbo.dim_user') IS NOT NULL DROP TABLE dbo.dim_user;
GO

SELECT user_id,
       MIN(event_time) AS first_seen,
       MAX(event_time) AS last_seen
INTO dbo.dim_user
FROM dbo.events_clean
GROUP BY user_id;
GO

ALTER TABLE dbo.dim_user ALTER COLUMN user_id BIGINT NOT NULL;
GO
ALTER TABLE dbo.dim_user ADD CONSTRAINT PK_dim_user PRIMARY KEY (user_id);
GO

-- DIM_PRODUCT
IF OBJECT_ID('dbo.dim_product') IS NOT NULL DROP TABLE dbo.dim_product;
GO

SELECT product_id,
       MAX(category_id)   AS category_id,
       MAX(category_code) AS category_code,
       CASE WHEN MAX(category_code) IS NULL THEN 'unknown'
            WHEN CHARINDEX('.', MAX(category_code)) = 0 THEN MAX(category_code)
            ELSE LEFT(MAX(category_code), CHARINDEX('.', MAX(category_code)) - 1)
       END AS category_main,
       -- ưu tiên thương hiệu thật, dùng 'unknown' khi không có gì khác
       ISNULL(MAX(CASE WHEN brand <> 'unknown' THEN brand END), 'unknown') AS brand
INTO dbo.dim_product
FROM dbo.events_clean
GROUP BY product_id;
GO

ALTER TABLE dbo.dim_product ALTER COLUMN product_id BIGINT NOT NULL;
GO
ALTER TABLE dbo.dim_product ADD CONSTRAINT PK_dim_product PRIMARY KEY (product_id);
GO

-- DIM_DATE
IF OBJECT_ID('dbo.dim_date') IS NOT NULL DROP TABLE dbo.dim_date;
GO

WITH d AS (
    SELECT CAST(MIN(event_time) AS date) AS dt,
           CAST(MAX(event_time) AS date) AS dmax
    FROM dbo.events_clean
    UNION ALL
    SELECT DATEADD(DAY, 1, dt), dmax
    FROM d
    WHERE dt < dmax
)
SELECT CONVERT(INT, CONVERT(CHAR(8), dt, 112)) AS date_key,
       dt                                       AS full_date,
       DATEPART(WEEK, dt)                       AS week_no,
       DATENAME(WEEKDAY, dt)                    AS weekday_name,
       -- 0 = thứ Hai ... 6 = Chủ nhật
       CASE WHEN (DATEPART(WEEKDAY, dt) + @@DATEFIRST - 2) % 7 >= 5
            THEN 1 ELSE 0 END                   AS is_weekend
INTO dbo.dim_date
FROM d
OPTION (MAXRECURSION 400);
GO

ALTER TABLE dbo.dim_date ALTER COLUMN date_key INT NOT NULL;
GO
ALTER TABLE dbo.dim_date ADD CONSTRAINT PK_dim_date PRIMARY KEY (date_key);
GO

-- FACT_EVENTS
IF OBJECT_ID('dbo.fact_events') IS NOT NULL DROP TABLE dbo.fact_events;
GO

SELECT IDENTITY(BIGINT, 1, 1)                          AS event_id,
       event_time,
       CONVERT(INT, CONVERT(CHAR(8), event_time, 112)) AS date_key,
       user_id,
       product_id,
       event_type,
       price,
       user_session
INTO dbo.fact_events
FROM dbo.events_clean;
GO

ALTER TABLE dbo.fact_events ADD CONSTRAINT PK_fact_events PRIMARY KEY (event_id);

-- Index tăng tốc truy vấn 
CREATE INDEX IX_fact_user_time ON dbo.fact_events (user_id, event_time);
CREATE INDEX IX_fact_date_type ON dbo.fact_events (date_key, event_type);
CREATE INDEX IX_fact_product   ON dbo.fact_events (product_id);
GO

-- KIỂM TRA

-- 1. Số dòng các bảng
SELECT 'fact_events' AS tbl, COUNT(*) AS n FROM dbo.fact_events
UNION ALL SELECT 'dim_user',    COUNT(*) FROM dbo.dim_user
UNION ALL SELECT 'dim_product', COUNT(*) FROM dbo.dim_product
UNION ALL SELECT 'dim_date',    COUNT(*) FROM dbo.dim_date;

-- 2. Kiểm tra khóa ngoại
SELECT
  (SELECT COUNT(*) FROM dbo.fact_events f
     LEFT JOIN dbo.dim_user u    ON f.user_id    = u.user_id    WHERE u.user_id    IS NULL) AS orphan_user,
  (SELECT COUNT(*) FROM dbo.fact_events f
     LEFT JOIN dbo.dim_product p ON f.product_id = p.product_id WHERE p.product_id IS NULL) AS orphan_product,
  (SELECT COUNT(*) FROM dbo.fact_events f
     LEFT JOIN dbo.dim_date d    ON f.date_key   = d.date_key   WHERE d.date_key   IS NULL) AS orphan_date;
GO