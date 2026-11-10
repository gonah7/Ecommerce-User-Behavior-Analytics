CREATE DATABASE EcomBehavior;
GO
USE EcomBehavior;
GO

CREATE TABLE dbo.raw_events (
    event_time    NVARCHAR(50)  NULL,
    event_type    NVARCHAR(30)  NULL,
    product_id    BIGINT        NULL,
    category_id   BIGINT        NULL,
    category_code NVARCHAR(200) NULL,
    brand         NVARCHAR(100) NULL,
    price         DECIMAL(12,2) NULL,
    user_id       BIGINT        NULL,
    user_session  NVARCHAR(100) NULL
);
GO


BULK INSERT dbo.raw_events
FROM 'C:\data\events_sample.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    KEEPNULLS,
    TABLOCK
);

-- 1. Tổng số dòng 
SELECT COUNT(*) AS total_rows FROM dbo.raw_events;

-- 2. Phân bố loại sự kiện
SELECT event_type, COUNT(*) AS n
FROM dbo.raw_events
GROUP BY event_type
ORDER BY n DESC;

-- 3. Số user khác nhau 
SELECT COUNT(DISTINCT user_id) AS total_users FROM dbo.raw_events;

-- 4. Xem 10 dòng
SELECT TOP 10 * FROM dbo.raw_events;