-- ================================================================================================
-- Script: fill_dw_from_agg.sql

-- Purpose:
-- This SQL script populates the data warehouse (DW) from the aggregated 15-minute 
--  stock price data in the staging area. 
-- It performs the following steps:
-- 1. Inserts an audit log entry for the data loading process.
-- 2. Upserts records into the dimension tables (dim_date, dim_company, dim_instrument, 
--    dim_exchange) based on the aggregated data and company information in staging.
-- 3. Creates temporary tables to enrich the fact data with calculated fields such as VWAP, 
--    previous close, price change, and price change percentage.
-- 4. Upserts the enriched fact data into the fact_15min_stock_price table, 
--    using a natural/business grain unique constraint to handle updates.
-- 5. Updates the audit log entry to mark the process as completed and records the execution time.

-- Intended Use:
-- This script is designed to be run in a PostgreSQL environment as part of the ELT process 
--  to populate the data warehouse. 
-- It should be executed after the aggregated 15-minute data has been loaded into the 
--  core_staging.agg_15min_raw table and the company information is available in 
--  core_staging.stg_companies.

-- Usage:
-- 1. Ensure that the aggregated data is loaded into core_staging.agg_15min_raw and 
--    company data is in core_staging.stg_companies.
-- 2. Run this script in your PostgreSQL database to populate the DW dimensions and fact table.

-- Output:
-- - Populated dimension tables (dim_date, dim_company, dim_instrument, dim_exchange) in the 'dw' schema.
-- - Populated fact table (fact_15min_stock_price) with enriched stock price data
-- - Updated audit log entry in dim_meta_audit_log with execution details.

-- Author: Emilio Iturbide Gonzalez
-- License: MIT
-- ================================================================================================

DO $$
DECLARE
  v_audit_id BIGINT;
  v_schema_name TEXT := 'dw'; -- Change this to your desired schema name; must match the schema where your star schema tables are located.
  v_min_date DATE;
  v_max_date DATE;
  v_load_status TEXT;
  
BEGIN
  -- ================================================================================================
  -- 1) Insert an audit row for this run and capture the generated sk_audit_id for use in the fact table records
  -- ================================================================================================
  RAISE NOTICE 'Inserting audit log entry for DW load process...';
  EXECUTE FORMAT('
    INSERT INTO %I.dim_meta_audit_log(source_system, row_count_raw, row_count_rejected, 
                                      execution_start_ts, execution_end_ts, execution_time, status)
      VALUES (%L, (SELECT COUNT(*) FROM %I.agg_15min_raw), 0, NOW(), NULL, 0, %L)
    RETURNING sk_audit_id;', v_schema_name, 'DW_UPSERT', v_schema_name, 'started') 
    INTO v_audit_id;

  RAISE NOTICE 'Audit log entry created with sk_audit_id: %', v_audit_id;
  -- ===============================================================================================
  -- 2) Get the min and max dates from the aggregated data to limit the date dimension upsert
  -- and to create any missing partitions for the fact table
  -- ===============================================================================================
  RAISE NOTICE 'Retrieving date range from aggregated data to create necessary partitions...';
  EXECUTE FORMAT('SELECT MIN(interval_start)::DATE, MAX(interval_start)::DATE + INTERVAL ''1 day'' FROM %I.agg_15min_raw', v_schema_name) 
    INTO v_min_date, v_max_date;

  RAISE NOTICE 'Date range for aggregated data: % to %', v_min_date, v_max_date;
  RAISE NOTICE 'Creating partitions for fact table based on date range...';
  IF v_min_date IS NOT NULL THEN
    EXECUTE FORMAT('CALL %I.create_fact_table_partitions($1, $2)', v_schema_name) 
    USING v_min_date, v_max_date;
  END IF;
  RAISE NOTICE 'Partitions created for fact table between % and %', v_min_date, v_max_date;

  -- ===============================================================================================
  -- 3) Upsert dim_date from aggregated intervals
  -- - We can derive all necessary date parts from the interval_start field in the agg_15min_raw table, 
  --    which represents the datetime of each 15-minute bar.
  -- - This approach ensures that we only insert dates that are relevant to our fact data, 
  --    and avoids the need to generate a large date dimension upfront.
  -- ===============================================================================================
  RAISE NOTICE 'Upserting dim_date from aggregated data intervals...';
  EXECUTE FORMAT('
      INSERT INTO %I.dim_date (sk_date_id, datetime, date, hour, minute, second, 
                              day_of_week, day_name, day_of_month, day_of_year, 
                              week_of_month, week_of_year, month, month_name, year, 
                              quarter, is_weekend, is_holiday, fiscal_year, fiscal_quarter,
                              granularity, is_early_close, is_pre_market, is_regular_session, is_after_hours, 
                              timezone)
      WITH base_data AS (
        SELECT DISTINCT
          TO_CHAR(interval_start, ''YYYYMMDDHH24MISS'')::bigint AS sk_date_id,
          interval_start::timestamp AS datetime,
          interval_start::date AS d_date,
          EXTRACT(hour FROM interval_start)::int AS h,
          EXTRACT(minute FROM interval_start)::int AS m,
          EXTRACT(second FROM interval_start)::int AS s,
          EXTRACT(dow FROM interval_start)::int AS dow,
          EXTRACT(day FROM interval_start)::int AS dom,
          EXTRACT(month FROM interval_start)::int AS mon,
          EXTRACT(year FROM interval_start)::int AS yr,
          granularity,
          timezone,
          -- Identify if today is an Early Close Day
          ((EXTRACT(month FROM interval_start) = 11 AND EXTRACT(day FROM interval_start) BETWEEN 23 AND 29 AND EXTRACT(dow FROM interval_start) = 5)
          OR (EXTRACT(month FROM interval_start) = 12 AND EXTRACT(day FROM interval_start) = 24)
          OR (EXTRACT(month FROM interval_start) = 7 AND EXTRACT(day FROM interval_start) = 3)) AS is_ec_day
        FROM %I.agg_15min_raw
      )
      SELECT 
        sk_date_id, datetime, d_date, h, m, s, 
        dow, TRIM(TO_CHAR(datetime, ''Day''))::text, dom, EXTRACT(doy FROM datetime)::int,
        TO_CHAR(datetime, ''W'')::int, EXTRACT(week FROM datetime)::int, mon, TRIM(TO_CHAR(datetime, ''Month''))::text, yr,
        EXTRACT(quarter FROM datetime)::int, (CASE WHEN dow IN (0,6) THEN true ELSE false END), false, yr, EXTRACT(quarter FROM datetime)::int,
        granularity,
        -- is_early_close: True only for intervals occurring AFTER 13:00 on an early close day
        (is_ec_day AND (h > 13 OR (h = 13 AND m >= 0))) AS is_early_close,
        -- is_pre_market: Standard logic
        (h < 9 OR (h = 9 AND m < 30)) AS is_pre_market,
        -- is_regular_session: Respects early close
        CASE 
          WHEN is_ec_day AND h >= 13 THEN false
          WHEN (h > 9 OR (h = 9 AND m >= 30)) AND (h < 16 OR (h = 16 AND m = 0)) THEN true 
          ELSE false 
        END AS is_regular_session,
        -- is_after_hours: Starts at 13:00 on Early Close days, 16:00 otherwise
        CASE 
          WHEN is_ec_day AND (h > 13 OR (h = 13 AND m >= 0)) THEN true
          WHEN h > 16 OR (h = 16 AND m > 0) THEN true
          ELSE false
        END AS is_after_hours,
        timezone
      FROM base_data
      ON CONFLICT (sk_date_id) DO NOTHING;', v_schema_name, v_schema_name
  );
  RAISE NOTICE 'dim_date upsert completed.';

  -- ===============================================================================================
  -- 4) Upsert company/instrument/exchange/trade_status dims from staging
  -- ===============================================================================================
  RAISE NOTICE 'Upserting dim_company, dim_instrument, dim_exchange, and dim_trade_status from staging...';
  EXECUTE FORMAT('
    INSERT INTO %I.dim_company (symbol, company_name, ceo, currency, sector, industry, 
                                full_time_employees, country, state, city, zip, address, 
                                ipo_date, is_active, is_etf, is_fund, row_effective_ts)
    SELECT DISTINCT 
      symbol, company_name, ceo, currency, sector, industry, full_time_employees, country, 
      state, city, zip, address, ipo_date, is_active, is_etf, is_fund, now()
    FROM core_staging.stg_companies
    ON CONFLICT (symbol) DO UPDATE 
      SET company_name = EXCLUDED.company_name;', v_schema_name
  );
  RAISE NOTICE 'dim_company upsert completed.';

  EXECUTE FORMAT('
    INSERT INTO %I.dim_instrument (instrument_type, symbol, name, currency)
    SELECT DISTINCT 
      a.symbol_type AS instrument_type, a.symbol, c.company_name AS name, c.currency
    FROM core_staging.stg_companies c
    RIGHT JOIN %I.agg_15min_raw a ON a.symbol = c.symbol
    ON CONFLICT (instrument_type, symbol) DO NOTHING;', v_schema_name, v_schema_name
  );
  RAISE NOTICE 'dim_instrument upsert completed.';

  EXECUTE FORMAT('
    INSERT INTO %I.dim_exchange (exchange_code, exchange_name)
    SELECT DISTINCT 
      exchange AS exchange_code, exchange_full_name AS exchange_name
    FROM core_staging.stg_companies
    ON CONFLICT (exchange_code) DO NOTHING;', v_schema_name
  );
  RAISE NOTICE 'dim_exchange upsert completed.';

  EXECUTE FORMAT('
    INSERT INTO %I.dim_trade_status (agg_status, agg_trade_count)
    SELECT DISTINCT 
      CASE 
        WHEN trade_count = 0 THEN ''non-existent''
        WHEN trade_count < 3 THEN ''partial''
        ELSE ''complete''
      END AS agg_status,
        
      trade_count AS agg_trade_count
    FROM %I.agg_15min_raw
    ON CONFLICT (agg_status) DO NOTHING;', v_schema_name, v_schema_name
  );
  RAISE NOTICE 'dim_trade_status upsert completed.';

  -- ===============================================================================================
  -- 5) Build enriched bars (with previous_close) into a temp table
  -- - This allows us to compute all necessary fields and join to dimensions 
  --    before the final upsert into the fact table
  -- - We calculate VWAP using a window function that sums the typical price * volume and 
  --    divides by the cumulative volume for each symbol and date
  -- - We also calculate previous_close using a window function that looks at the previous 
  --    row for each symbol ordered by interval_start
  -- ===============================================================================================
  RAISE NOTICE 'Creating enriched temp table with calculated fields (VWAP, previous_close, etc.)...';
  EXECUTE FORMAT('
    CREATE TEMP TABLE temp_enriched ON COMMIT DROP AS
    SELECT
      a.symbol,
      a.interval_start,
      a.open::numeric(18,6) AS open_price,
      a.high::numeric(18,6) AS high_price,
      a.low::numeric(18,6) AS low_price,
      a.close::numeric(18,6) AS close_price,
      a.volume::bigint AS volume,
      -- calculate adj_close, VWAP, previous_close, price_change, price_change_pct
      CASE WHEN a.volume = 0 THEN NULL
           ELSE a.close::numeric END AS adj_close,
      CASE WHEN a.volume = 0 THEN NULL
           ELSE SUM(((a.high + a.low + a.close) / 3) * a.volume) OVER (
                PARTITION BY a.symbol, DATE(a.interval_start) ORDER BY a.interval_start
                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) / NULLIF(SUM(a.volume) OVER (
                PARTITION BY a.symbol, DATE(a.interval_start) ORDER BY a.interval_start
                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ), 0) END::NUMERIC(18, 6) AS vwap,
      LAG(a.close) OVER (PARTITION BY a.symbol ORDER BY a.interval_start) AS previous_close
    FROM %I.agg_15min_raw a;', v_schema_name, v_schema_name
  );
  RAISE NOTICE 'Enriched temp table created.';

  -- ===============================================================================================
  -- 6) Join dims to generate FK ids and compute deltas
    -- - We join the enriched temp table to the dimension tables to get the surrogate keys 
    --    for date, instrument, exchange, and company
    -- - We also compute price_change and price_change_pct here so that we can use them 
    --    in the upsert to the fact table
    -- - The ON CONFLICT clause in the final insert will handle both inserts and 
    --    updates based on the natural/business key of (fk_date_id, fk_instrument_id)
    -- - This ensures that if we reprocess data for a given date and instrument, 
    --    we will update the existing fact record rather than creating duplicates
  -- ===============================================================================================
  RAISE NOTICE 'Joining dimensions to generate foreign keys and compute deltas for fact table...';
  EXECUTE FORMAT('
    CREATE TEMP TABLE temp_fact ON COMMIT DROP AS
    SELECT
      d.sk_date_id AS fk_date_id,
      i.sk_instrument_id AS fk_instrument_id,
      e.sk_exchange_id AS fk_exchange_id,
      %1$L::BIGINT AS fk_audit_id,
      c.sk_company_id AS fk_company_id,
      s.sk_status_id AS fk_status_id,
      t.open_price,
      t.high_price,
      t.low_price,
      t.close_price,
      t.volume,
      t.close_price AS adj_close,
      t.vwap,
      t.previous_close,
      (t.close_price - t.previous_close) AS price_change,
      CASE WHEN t.previous_close IS NULL OR t.previous_close = 0 THEN 0
           ELSE ((t.close_price - t.previous_close) / t.previous_close) * 100 END::NUMERIC(7, 3) AS price_change_pct,
      (t.high_price - t.low_price) AS price_range
    FROM temp_enriched t
    LEFT JOIN %2$I.dim_company c ON c.symbol = t.symbol
    LEFT JOIN %2$I.dim_instrument i ON i.symbol = t.symbol
    LEFT JOIN %2$I.dim_exchange e ON e.exchange_code = (SELECT exchange FROM core_staging.stg_companies WHERE symbol = t.symbol LIMIT 1)
    LEFT JOIN %2$I.dim_trade_status s ON s.agg_trade_count = (SELECT trade_count FROM %2$I.agg_15min_raw WHERE symbol = t.symbol AND interval_start = t.interval_start LIMIT 1)
    LEFT JOIN %2$I.dim_date d ON d.datetime = t.interval_start;', v_audit_id, v_schema_name
  );
  RAISE NOTICE 'Temp fact table with foreign keys and calculated fields created.';

  -- ===============================================================================================
  -- 7) Upsert into fact table using the natural/business grain unique constraint
  -- - The ON CONFLICT clause will update existing records for the same date and instrument,
  --    which allows us to handle reprocessing of data without creating duplicates
  -- - We update all relevant fields in the fact table, including the foreign keys and 
  --    calculated measures
  -- - This ensures that our fact table always has the most up-to-date information 
  --    for each date and instrument combination
  -- ===============================================================================================
  RAISE NOTICE 'Upserting enriched fact data into fact_15min_stock_price table...';
  EXECUTE FORMAT('
    INSERT INTO %I.fact_15min_stock_price (fk_date_id, fk_instrument_id, fk_exchange_id, 
                                           fk_audit_id, fk_company_id, fk_status_id, open_price, 
                                           high_price, low_price, close_price, volume, adj_close, 
                                           vwap, previous_close, price_change, price_change_pct, 
                                           price_range)
    SELECT fk_date_id, fk_instrument_id, fk_exchange_id, fk_audit_id, fk_company_id, fk_status_id,
           open_price, high_price, low_price, close_price, volume, 
           adj_close, vwap, previous_close, price_change, price_change_pct, price_range
    FROM temp_fact
    ON CONFLICT (fk_date_id, fk_instrument_id) DO UPDATE
      SET open_price = EXCLUDED.open_price,
          high_price = EXCLUDED.high_price,
          low_price = EXCLUDED.low_price,
          close_price = EXCLUDED.close_price,
          volume = EXCLUDED.volume,
          adj_close = EXCLUDED.adj_close,
          vwap = EXCLUDED.vwap,
          previous_close = EXCLUDED.previous_close,
          price_change = EXCLUDED.price_change,
          price_change_pct = EXCLUDED.price_change_pct,
          price_range = EXCLUDED.price_range,
          fk_audit_id = EXCLUDED.fk_audit_id,
          fk_company_id = EXCLUDED.fk_company_id,
          fk_status_id = EXCLUDED.fk_status_id,
          fk_exchange_id = EXCLUDED.fk_exchange_id;', v_schema_name
  );
  RAISE NOTICE 'Fact table upsert completed.';

  -- ===============================================================================================
  -- 8) Mark the audit log entry as completed and record the execution time
  -- - We update the status to 'completed', set the execution_end_ts to the 
  --    current timestamp, and calculate the execution_time as the difference between 
  --    the start and end timestamps
  -- - This allows us to track the performance of our data loading process and identify 
  --    any potential bottlenecks or issues in future runs
  -- ===============================================================================================
  RAISE NOTICE 'Updating audit log entry to mark process as completed...';
  EXECUTE FORMAT('
    UPDATE %I.dim_meta_audit_log 
    SET status = ''completed'', 
        execution_end_ts = CLOCK_TIMESTAMP(), 
        execution_time = EXTRACT(EPOCH FROM (CLOCK_TIMESTAMP() - execution_start_ts))  
    WHERE sk_audit_id = %L;', v_schema_name, v_audit_id
  );
  RAISE NOTICE 'Audit log entry updated with completion status and execution time.';
  --RAISE NOTICE 'Execution time (seconds): %',
  --  (SELECT execution_time FROM %I.dim_meta_audit_log WHERE sk_audit_id = v_audit_id)
  --  USING v_schema_name;
  RAISE NOTICE 'DW load process completed successfully.';

  -- =================================================================================================
  -- Update the elt_control table with the last processed timestamp and status for incremental processing
  -- =================================================================================================
  RAISE NOTICE 'Updating elt_control table with last processed timestamp and status...';
  EXECUTE format('
    UPDATE %I.elt_control
    SET last_processed = (SELECT MAX(interval_start) FROM %I.agg_15min_raw),
        last_run_ts = clock_timestamp(),
        status = %L
    WHERE job_name = %L;', v_schema_name, v_schema_name, 'completed', 'agg_15min_job'
  );
  -- ================================================================================================
  -- If DW load is successful, we can truncate the aggregated staging table to free up space
  -- ================================================================================================
  RAISE NOTICE 'Truncating aggregated staging table to free up space...';
  EXECUTE format('SELECT status FROM %I.dim_meta_audit_log WHERE sk_audit_id = %L', v_schema_name, v_audit_id)
        INTO v_load_status;
  IF v_load_status = 'completed' THEN
    EXECUTE format('TRUNCATE TABLE %I.agg_15min_raw', v_schema_name);
    RAISE NOTICE 'Aggregated staging table truncated.';
  ELSE
    RAISE WARNING 'DW load did not complete successfully. Aggregated staging table has not been truncated for review.';
  END IF;

END $$;
