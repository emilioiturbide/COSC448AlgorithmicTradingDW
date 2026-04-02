-- ================================================================================================
-- Script: agg_incremental.sql

-- Purpose:
-- This SQL script performs incremental aggregation of raw stock price data into 15-minute intervals, 
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
    v_schema_name TEXT := 'dw';
    v_table_name TEXT := 'agg_15min_raw';
    v_granularity_interval TEXT := '15';
    v_last_processed TIMESTAMP;
BEGIN
    -- =================================================================================================
    -- 1) Create the aggregated table and elt_control table if these don't exist
    -- This table will store the aggregated 15-minute OHLCV and VWAP data for each stock symbol.
    -- The primary key is a combination of symbol and interval_start to ensure uniqueness
    --  of each 15-minute bar.
    -- =================================================================================================
    EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', v_schema_name);
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.elt_control (
            id SERIAL PRIMARY KEY,
            job_name VARCHAR(255),
            last_processed TIMESTAMP WITHOUT TIME ZONE NOT NULL,
            last_run_ts TIMESTAMP WITHOUT TIME ZONE NOT NULL,
            status VARCHAR(50)
        )
    ', v_schema_name);
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
    -- Check if the elt_control table has an entry for this job, If yes, get the last processed timestamp
    -- =================================================================================================
    EXECUTE format('SELECT last_processed FROM %I.elt_control WHERE job_name = %L', v_schema_name, 'agg_15min_job')
        INTO v_last_processed;

    -- =================================================================================================
    -- If there is a last processed timestamp, use it to filter the data. Otherwise, process all data.
    -- =================================================================================================
    IF v_last_processed IS NOT NULL THEN
        RAISE NOTICE 'Last processed timestamp found: %. Processing data from this timestamp onward.', v_last_processed;
        EXECUTE format('
            WITH ticks AS (
            SELECT ticker_symbol, timezone, symbol_type, trade_date, open_price, high_price, low_price, close_price, volume,
                (date_trunc(''minute'', trade_date) - (EXTRACT(minute FROM trade_date)::int %% %L) * INTERVAL ''1 minute'') AS interval_start
            FROM core_staging.stg_stock_price
            WHERE trade_date > %L
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
                granularity = EXCLUDED.granularity;', v_granularity_interval, v_last_processed, v_schema_name, v_table_name, v_granularity_interval || 'min');
    ELSE
        RAISE NOTICE 'No last processed timestamp found. Processing all data.';
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
    END IF;

    -- =================================================================================================
    -- Update the elt_control table with the current timestamp as last processed and last run timestamp,
    -- and set status to 'completed'.
    -- =================================================================================================

    IF v_last_processed IS NOT NULL THEN
        EXECUTE format('
            UPDATE %I.elt_control
            SET last_processed = (SELECT MAX(interval_start) FROM %I.%I WHERE interval_start < clock_timestamp()), 
                last_run_ts = clock_timestamp(), 
                status = %L
            WHERE job_name = %L
        ', v_schema_name, v_schema_name, v_table_name, 'started', 'agg_15min_job');
    ELSE
        EXECUTE format('
            INSERT INTO %I.elt_control (job_name, last_processed, last_run_ts, status)
            VALUES (%L, (SELECT MAX(interval_start) FROM %I.%I WHERE interval_start < clock_timestamp()), clock_timestamp(), %L)
        ', v_schema_name, 'agg_15min_job', v_schema_name, v_table_name, 'started');
    END IF;
END $$;