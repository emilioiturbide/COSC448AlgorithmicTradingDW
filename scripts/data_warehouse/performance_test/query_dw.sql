-- ==============================================================================
-- Script: query_dw.sql

-- Copyright (c) 2026 Emilio Iturbide Gonzalez
-- This software is licensed under the MIT License, located in the root directory
--   of this project (LICENSE file).
-- ===============================================================================

-- Use of AI:
-- Github Copilot AI was used to help debug the implementation of the script.
-- All AI-generated suggestions were reviewed, verified, and modified by the author
--   before inclusion.

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
-- Date Created: 02/05/2026
-- Date Last Modified: 04/20/2026
-- License: MIT
-- ==============================================================================

-- =============================================================================
-- BI Queries for demonstration purposes
-- =============================================================================

-- Query description: Retrieves the Monthly OHLCV data for the AAPL stock on 2025.
SELECT
    Month,
    Month_Number,
    Year,
    Symbol,
    MAX(CASE WHEN row_asc = 1 THEN open_price END) AS Open,
    MAX(high_price) AS High,
    MIN(low_price) AS Low,
    MAX(CASE WHEN row_desc = 1 THEN close_price END) AS Close,
    SUM(volume) AS Volume
FROM (
    SELECT
        d.month_name AS Month,
        d.month AS Month_Number,
        d.year AS Year,
        i.symbol AS Symbol,
        f.open_price,
        f.high_price,
        f.low_price,
        f.close_price,
        f.volume,
        ROW_NUMBER() OVER(PARTITION BY d.month ORDER BY f.fk_date_id ASC) AS row_asc,
        ROW_NUMBER() OVER(PARTITION BY d.month ORDER BY f.fk_date_id DESC) AS row_desc
    FROM dw.fact_15min_stock_price f
    JOIN dw.dim_date d ON f.fk_date_id = d.sk_date_id
    JOIN dw.dim_instrument i ON f.fk_instrument_id = i.sk_instrument_id
    WHERE i.symbol = 'AAPL' AND d.year = 2025
) sub
GROUP BY Month, Month_Number, Year, Symbol
ORDER BY Month_Number;


-- Query description: Calculates the daily closing price and the 50-day Simple Moving Average (SMA) 
--  for the AAPL stock

SELECT 
    d.datetime AS day,
    f.close_price AS close,
    AVG(f.close_price) OVER (ORDER BY d.date ROWS BETWEEN 49 PRECEDING AND CURRENT ROW) AS sma_50
FROM dw.fact_15min_stock_price f
JOIN dw.dim_instrument i ON f.fk_instrument_id = i.sk_instrument_id
JOIN dw.dim_date d ON f.fk_date_id = d.sk_date_id
WHERE i.symbol = 'AAPL'
ORDER BY day DESC;

-- Query Description: Calculates the daily percentage change from the first trade to the last trade
--  of a specific day, grouped by stock symbol.
WITH daily_prices AS (
    SELECT 
        i.symbol AS symbol,
        d.date AS trade_date,
        (array_agg(f.open_price ORDER BY d.datetime ASC))[1] AS open,
        (array_agg(f.close_price ORDER BY d.datetime DESC))[1] AS close
    FROM dw.fact_15min_stock_price f
    JOIN dw.dim_instrument i ON f.fk_instrument_id = i.sk_instrument_id
    JOIN dw.dim_date d ON f.fk_date_id = d.sk_date_id
    WHERE f.fk_date_id >= TO_CHAR('2024-03-01'::timestamp, 'YYYYMMDDHH24MISS')::bigint AND
          f.fk_date_id < TO_CHAR('2024-03-02'::timestamp, 'YYYYMMDDHH24MISS')::bigint
    GROUP BY i.symbol, d.date
)
SELECT 
    symbol,
    trade_date,
    open,
    close,
    ((close - open) / open) * 100 AS pct_change
FROM daily_prices
ORDER BY pct_change DESC;


-- Query Description: Calculates the volatility based on the high-low range compared 
--  to the opening price for the specified day.
SELECT 
    i.symbol,
    MAX(f.high_price) AS daily_high,
    MIN(f.low_price) AS daily_low,
    ((MAX(f.high_price) - MIN(f.low_price)) / MIN(f.low_price)) * 100 AS volatility_pct
FROM dw.fact_15min_stock_price f
JOIN dw.dim_instrument i ON f.fk_instrument_id = i.sk_instrument_id
WHERE f.fk_date_id >= TO_CHAR('2024-03-01'::timestamp, 'YYYYMMDDHH24MISS')::bigint AND
      f.fk_date_id < TO_CHAR('2024-03-02'::timestamp, 'YYYYMMDDHH24MISS')::bigint
GROUP BY i.symbol
ORDER BY volatility_pct DESC
LIMIT 5;


-- Query description: Retrieves the execution plan of a query that selects total volume and average price data
--                    for the month of March on 2024 and 2026
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, COSTS)
SELECT ticker_symbol, SUM(volume) AS Total_Volume, AVG(close_price) AS Avg_Price 
FROM core_staging.stg_stock_price
WHERE trade_date BETWEEN '2026-03-01' AND '2026-04-01' OR
trade_date BETWEEN '2024-03-01' AND '2024-04-01'
GROUP BY ticker_symbol;

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, COSTS)
SELECT symbol, SUM(volume) AS Total_Volume, AVG(close) AS Avg_Price
FROM dw_test.agg_15min_raw
WHERE interval_start BETWEEN '2026-03-01' AND '2026-04-01' OR
	interval_start BETWEEN '2024-03-01' AND '2024-04-01'
GROUP BY symbol;

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, COSTS)
SELECT 
    i.symbol,
    SUM(f.volume) AS Total_Volume,
    AVG(f.close_price) AS Avg_Price
FROM dw.fact_15min_stock_price f
JOIN dw.dim_instrument i ON f.fk_instrument_id = i.sk_instrument_id
JOIN dw.dim_date dt ON f.fk_date_id = dt.sk_date_id
WHERE dt.month_name = 'March' AND (dt.year = 2026 OR dt.year = 2024)
GROUP BY i.symbol;


-- Query description: Same as above but with partition pruning enabled.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, COSTS)
SELECT 
    i.symbol,
    SUM(f.volume) AS Total_Volume,
    AVG(f.close_price) AS Avg_Price
FROM dw.fact_15min_stock_price f
JOIN dw.dim_instrument i ON f.fk_instrument_id = i.sk_instrument_id
JOIN dw.dim_date dt ON f.fk_date_id = dt.sk_date_id
WHERE f.fk_date_id BETWEEN TO_CHAR('2026-03-01'::timestamp, 'YYYYMMDDHH24MISS')::bigint AND TO_CHAR('2026-04-01'::timestamp, 'YYYYMMDDHH24MISS')::bigint OR
f.fk_date_id BETWEEN TO_CHAR('2024-03-01'::timestamp, 'YYYYMMDDHH24MISS')::bigint AND TO_CHAR('2024-04-01'::timestamp, 'YYYYMMDDHH24MISS')::bigint
GROUP BY i.symbol;