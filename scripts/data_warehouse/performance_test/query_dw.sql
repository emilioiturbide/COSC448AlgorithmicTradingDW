-- ==============================================================================
-- Script: query_dw.sql

-- Purpose:
-- This script contains multiple queries that can be used to test the performance
--    of the star schema.

-- Intended Use:
-- This script is designed to be run as many times as desired.
-- It is useful for scenarios when you want to test the query execution time of the
--    star schema.

-- Usage:
-- 1. Ensure the star schema is properly configured with it's necessary tables and data
-- 2. Run this script using psql or a UI software like pgadmin or PostgreSQL extension
--    tool.

-- Output:
-- The script will return the output of the SELECT statements.

-- Author: Emilio Iturbide Gonzalez
-- License: MIT
-- ==============================================================================

-- Query description: Retrieves monthly stock market data including OHLCV metrics for each stock symbol, grouped by month, year, and symbol.
SELECT
  d.month_name,
  d.year,
  i.symbol,
    MAX(f.open_price) AS open_price,
    MAX(f.high_price) AS high_price,
    MIN(f.low_price) AS low_price,
    MAX(f.close_price) AS close_price,
    SUM(f.volume) AS total_volume
FROM dw.fact_15min_stock_price f
JOIN dw.dim_date d ON f.fk_date_id = d.sk_date_id
JOIN dw.dim_instrument i ON f.fk_instrument_id = i.sk_instrument_id
GROUP BY d.month_name, d.year, i.symbol
ORDER BY d.year, i.symbol;


-- Query description: Retrieves the execution plan of a query that selects total volume and average price data
--                    for the month of March on 2024 and 2026
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, COSTS)
SELECT 
    i.symbol,
    c.country,
    SUM(f.volume) as Total_Volume,
    AVG(f.close_price) as Avg_Price
FROM dw.fact_15min_stock_price f
JOIN dw.dim_instrument i ON f.fk_instrument_id = i.sk_instrument_id
JOIN dw.dim_date dt ON f.fk_date_id = dt.sk_date_id
JOIN dw.dim_company c ON f.fk_company_id = c.sk_company_id
WHERE dt.month_name = 'March' AND (dt.year = 2026 OR dt.year = 2024)
GROUP BY i.symbol, c.country;


-- Query description: Same as above but with partition pruning enabled.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, COSTS)
SELECT 
    i.symbol,
    c.country,
    SUM(f.volume) as Total_Volume,
    AVG(f.close_price) as Avg_Price
FROM dw.fact_15min_stock_price f
JOIN dw.dim_instrument i ON f.fk_instrument_id = i.sk_instrument_id
JOIN dw.dim_date dt ON f.fk_date_id = dt.sk_date_id
JOIN dw.dim_company c ON f.fk_company_id = c.sk_company_id
WHERE f.fk_date_id BETWEEN TO_CHAR('2026-03-01'::timestamp, 'YYYYMMDDHH24MISS')::bigint AND TO_CHAR('2026-04-01'::timestamp, 'YYYYMMDDHH24MISS')::bigint OR
f.fk_date_id BETWEEN TO_CHAR('2024-03-01'::timestamp, 'YYYYMMDDHH24MISS')::bigint AND TO_CHAR('2024-04-01'::timestamp, 'YYYYMMDDHH24MISS')::bigint
GROUP BY i.symbol, c.country;


-- Query description: Retrieves the execution plan of a query that selects OHLCV data for the AAPL stock
--                    during July 2024
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, COSTS) 
SELECT f.* 
FROM dw_test.fact_15min_stock_price f 
JOIN dw_test.dim_instrument i ON f.fk_instrument_id = i.sk_instrument_id
WHERE f.fk_date_id BETWEEN TO_CHAR('2024-07-03'::timestamp, 'YYYYMMDDHH24MISS')::bigint AND TO_CHAR('2024-08-03'::timestamp, 'YYYYMMDDHH24MISS')::bigint
	AND i.symbol = 'AAPL';


-- Query description: Same as above but without partition pruning.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, COSTS)
SELECT f.*
FROM dw_test.fact_15min_stock_price f
JOIN dw_test.dim_instrument i ON f.fk_instrument_id = i.sk_instrument_id
JOIN dw_test.dim_date d ON f.fk_date_id = d.sk_date_id
WHERE d.date BETWEEN '2024-07-03' AND '2024-08-03'
AND i.symbol = 'AAPL';

