-- ================================================================================================
-- Script: agg_15min.sql

-- Purpose:
-- This SQL script performs aggregation of raw stock price data into 15-minute intervals, 
--  calculating OHLCV and VWAP metrics.
-- It creates a new table 'agg_15min_raw' in the 'core_staging' schema 
--  to store the aggregated results.

-- Intended Use:
-- This script is designed to be run periodically (e.g., daily or hourly) to process 
--  new stock price data as it arrives in the 'stg_stock_price' staging table.
-- The aggregated data can then be used to populate the fact table in the 
--  data warehouse or for analytical queries.

-- Usage:
-- 1. Ensure that the 'stg_stock_price' table in the 'core_staging' schema is populated 
--  with raw stock price data.
-- 2. Run this script to create the 'agg_15min_raw' table and populate it with aggregated data.
-- 3. Use the aggregated data for further transformations or loading into the data warehouse.

-- Output:
-- - A new table 'core_staging.agg_15min_raw' containing aggregated 15-minute OHLCV and VWAP data 
--    for each stock symbol.

-- Author: Emilio Iturbide Gonzalez
-- License: MIT
-- ================================================================================================

DO $$
DECLARE
  v_schema_name TEXT := 'dw_test';
  v_table_name TEXT := 'agg_15min_raw';
  v_granularity_interval TEXT := '15';
BEGIN
  -- =================================================================================================
  -- 1) Create the aggregated table if it doesn't exist
  -- This table will store the aggregated 15-minute OHLCV and VWAP data for each stock symbol.
  -- The primary key is a combination of symbol and interval_start to ensure uniqueness 
  --  of each 15-minute bar.
  -- =================================================================================================
  EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', v_schema_name);

  EXECUTE format('
    CREATE TABLE IF NOT EXISTS %I.%I (
      symbol TEXT NOT NULL,
      symbol_type TEXT NOT NULL,
      interval_start TIMESTAMP WITHOUT TIME ZONE NOT NULL,
      timezone VARCHAR(50) NOT NULL,
      open NUMERIC,
      high NUMERIC,
      low NUMERIC,
      close NUMERIC,
      volume BIGINT,
      trade_count INTEGER,
      granularity VARCHAR(20),
      PRIMARY KEY (symbol, interval_start)
    )', v_schema_name, v_table_name);

  -- =================================================================================================
  -- 2) Populate the aggregated table for a time window (use WHERE to limit range if needed)
  -- We use a Common Table Expression (CTE) to first calculate the interval_start for each trade,
  --  which is the timestamp truncated to the nearest 15-minute interval.
  -- Then we aggregate the data by symbol, symbol_type, and interval_start to calculate:
  -- - open: the first price in the interval
  -- - high: the maximum price in the interval
  -- - low: the minimum price in the interval
  -- - close: the last price in the interval
  -- - volume: the total volume traded in the interval
  -- - trade_count: the number of trades in the interval
  -- We use ON CONFLICT to handle cases where the same symbol and interval_start already exist,
  --  allowing us to update the existing record with new aggregated values if necessary.
  -- =================================================================================================
  EXECUTE format('
    WITH ticks AS (
      SELECT ticker_symbol, timezone, symbol_type, trade_date, open_price, high_price, low_price, close_price, volume,
        (date_trunc(''minute'', trade_date) - (EXTRACT(minute FROM trade_date)::int %% %L) * INTERVAL ''1 minute'') AS interval_start
      FROM core_staging.stg_stock_price
    )
    INSERT INTO %I.%I (symbol, symbol_type, interval_start, timezone, open, high, low, close, volume, trade_count, granularity)
    SELECT
      ticker_symbol,
      symbol_type,
      interval_start,
      timezone,
      (ARRAY_AGG(open_price ORDER BY trade_date))[1]::numeric      AS open,
      MAX(high_price)::numeric                                     AS high,
      MIN(low_price)::numeric                                     AS low,
      (ARRAY_AGG(close_price ORDER BY trade_date DESC))[1]::numeric AS close,
      SUM(volume)::bigint                                     AS volume,
      COUNT(*)::int                                           AS trade_count,
      %L::VARCHAR(20)                                    AS granularity
    FROM ticks
    GROUP BY ticker_symbol, symbol_type, interval_start, timezone
    ON CONFLICT (symbol, interval_start) DO UPDATE
      SET open = EXCLUDED.open,
          high = EXCLUDED.high,
          low = EXCLUDED.low,
          close = EXCLUDED.close,
          volume = EXCLUDED.volume,
          trade_count = EXCLUDED.trade_count,
          symbol_type = EXCLUDED.symbol_type,
          granularity = EXCLUDED.granularity;', v_granularity_interval, v_schema_name, v_table_name, v_granularity_interval || 'min');
END $$;
