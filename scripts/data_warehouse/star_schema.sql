-- ====================================================================
-- Star Schema for Stock Price Data Warehouse

-- Script: star_schema.sql

-- Purpose: 
-- This SQL script defines a star schema for a data warehouse focused on stock price data. 
-- It includes dimension tables for date, exchange, company, audit logs, and financial instruments, 
-- as well as a fact table for 15-minute stock price data. The fact table is partitioned by date to optimize query performance.

-- Intended Use: 
-- This schema is designed to support analytical queries on stock price data, enabling users to analyze trends, 
-- compare performance across companies and exchanges, and track historical price movements. 
-- The audit log dimension allows for tracking of data loading processes, while the instrument dimension provides flexibility 
-- for different types of financial instruments.

-- Usage:
-- 1. Run this script to create the schema and tables in your PostgreSQL database.
-- 2. Use the provided procedure to create monthly partitions for the fact table.

-- Output:
-- - A set of tables in the 'dw' schema representing the star schema for the stock price data warehouse.

-- Author: Emilio Iturbide Gonzalez
-- License: MIT
-- ====================================================================

DO $$
DECLARE
    v_schema_name TEXT := 'dw'; -- Change this to your desired schema name
BEGIN
    -- ==============================================================
    -- Create schema if it doesn't exist
    -- ==============================================================
    EXECUTE FORMAT('CREATE SCHEMA IF NOT EXISTS %I', v_schema_name);

    -- ==============================================================
    -- Create schema tables
    -- ==============================================================

    -- ===============================================================
    -- dim_date table creation
    -- ===============================================================
    EXECUTE FORMAT('
        CREATE TABLE IF NOT EXISTS %I.dim_date (
            sk_date_id BIGINT PRIMARY KEY,
            datetime TIMESTAMP UNIQUE,
            date DATE,
            hour INT,
            minute INT,
            second INT,
            day_of_week INT,
            day_name VARCHAR(20),
            day_of_month INT,
            day_of_year INT,
            week_of_month INT,
            week_of_year INT,
            month INT,
            month_name VARCHAR(20),
            year INT,
            quarter INT,
            is_weekend BOOLEAN,
            is_holiday BOOLEAN,
            fiscal_year INT,
            fiscal_quarter INT,
            granularity VARCHAR(20),
            is_pre_market BOOLEAN,
            is_regular_session BOOLEAN,
            is_after_hours BOOLEAN,
            timezone VARCHAR(50),
            is_early_close BOOLEAN
        )', v_schema_name);

    -- =============================================================
    -- dim_exchange table creation
    -- =============================================================
    EXECUTE FORMAT('
        CREATE TABLE IF NOT EXISTS %I.dim_exchange (
            sk_exchange_id BIGSERIAL PRIMARY KEY,
            exchange_code VARCHAR(10) UNIQUE,
            exchange_name VARCHAR(255)
        )', v_schema_name);

    -- =============================================================
    -- dim_company table creation
    -- =============================================================
    EXECUTE FORMAT('
        CREATE TABLE IF NOT EXISTS %I.dim_company (
            sk_company_id BIGSERIAL PRIMARY KEY,
            symbol VARCHAR(10) UNIQUE,
            company_name VARCHAR(255),
            ceo VARCHAR(255),
            currency VARCHAR(10),
            sector VARCHAR(100),
            industry VARCHAR(100),
            full_time_employees INT,
            country VARCHAR(100),
            state VARCHAR(100),
            city VARCHAR(100),
            zip VARCHAR(20),
            address VARCHAR(255),
            ipo_date DATE,
            is_active BOOLEAN DEFAULT TRUE,
            is_etf BOOLEAN DEFAULT FALSE,
            is_fund BOOLEAN DEFAULT FALSE,
            row_effective_ts TIMESTAMP,
            row_end_ts TIMESTAMP
        )', v_schema_name);

    -- =============================================================
    -- dim_meta_audit_log table creation
    -- =============================================================
    EXECUTE FORMAT('
        CREATE TABLE IF NOT EXISTS %I.dim_meta_audit_log (
            sk_audit_id BIGSERIAL PRIMARY KEY,
            source_system VARCHAR(100),
            row_count_raw BIGINT,
            row_count_rejected BIGINT,
            execution_start_ts TIMESTAMP,
            execution_end_ts TIMESTAMP,
            execution_time DECIMAL(6, 2),
            status VARCHAR(50)
        )', v_schema_name);

    -- =============================================================
    -- dim_instrument table creation
    -- =============================================================
    EXECUTE FORMAT('
        CREATE TABLE IF NOT EXISTS %I.dim_instrument (
            sk_instrument_id BIGSERIAL PRIMARY KEY,
            instrument_type VARCHAR(50),
            symbol VARCHAR(10) UNIQUE,
            name VARCHAR(255),
            currency VARCHAR(10),
            CONSTRAINT unique_symbol UNIQUE (instrument_type, symbol)
        )', v_schema_name);
    
    -- ==============================================================
    -- dim_trade_status table creation
    -- ==============================================================
    EXECUTE FORMAT('
        CREATE TABLE IF NOT EXISTS %I.dim_trade_status (
            sk_status_id BIGSERIAL PRIMARY KEY,
            agg_status VARCHAR(20) UNIQUE,
            agg_trade_count INT
        )', v_schema_name);

    -- ==============================================================
    -- fact_15min_stock_price table creation (partitioned by fk_date_id)
    -- ==============================================================
    EXECUTE FORMAT('
        CREATE TABLE IF NOT EXISTS %I.fact_15min_stock_price (
            sk_fact_id BIGSERIAL,
            fk_date_id BIGINT,
            fk_instrument_id BIGINT,
            fk_exchange_id BIGINT,
            fk_audit_id BIGINT,
            fk_company_id BIGINT,
            fk_status_id BIGINT,

            open_price DECIMAL(18, 6),
            high_price DECIMAL(18, 6),
            low_price DECIMAL(18, 6),
            close_price DECIMAL(18, 6),
            volume BIGINT,
            adj_close DECIMAL(18, 6),
            vwap DECIMAL(18, 6),
            previous_close DECIMAL(18, 6),
            price_change DECIMAL(18, 6),
            price_change_pct DECIMAL(7, 3),
            price_range DECIMAL(18, 6),

            PRIMARY KEY (sk_fact_id, fk_date_id),
            UNIQUE (fk_date_id, fk_instrument_id),
            FOREIGN KEY (fk_date_id) REFERENCES %I.dim_date(sk_date_id),
            FOREIGN KEY (fk_instrument_id) REFERENCES %I.dim_instrument(sk_instrument_id),
            FOREIGN KEY (fk_audit_id) REFERENCES %I.dim_meta_audit_log(sk_audit_id),
            FOREIGN KEY (fk_company_id) REFERENCES %I.dim_company(sk_company_id),
            FOREIGN KEY (fk_exchange_id) REFERENCES %I.dim_exchange(sk_exchange_id),
            FOREIGN KEY (fk_status_id) REFERENCES %I.dim_trade_status(sk_status_id)
        ) PARTITION BY RANGE (fk_date_id)', v_schema_name, v_schema_name, v_schema_name, v_schema_name, v_schema_name, v_schema_name, v_schema_name);

    -- ==============================================================
    -- Create procedure to generate monthly partitions for the fact table
    -- ==============================================================
    EXECUTE FORMAT('
        CREATE OR REPLACE PROCEDURE %I.create_fact_table_partitions(start_date DATE, end_date DATE)
        LANGUAGE plpgsql
        AS $BODY$
        DECLARE
            current_m DATE := start_date;
            next_m DATE;
            suffix TEXT;
            partition_name TEXT;
            start_val BIGINT;
            end_val BIGINT;
            v_schema_name TEXT := %L;
        BEGIN
            WHILE current_m < end_date LOOP
                suffix := TO_CHAR(current_m, ''YYYYMM'');
                partition_name := ''fact_stock_'' || suffix;

                -- Start Value YYYYMM01000000
                start_val := (TO_CHAR(current_m, ''YYYYMM01000000''))::BIGINT;

                -- End Value: First day of next month YYYYMM01000000
                next_m := current_m + INTERVAL ''1 month'';
                end_val := (TO_CHAR(next_m, ''YYYYMM01000000''))::BIGINT;

                EXECUTE FORMAT(
                    ''CREATE TABLE IF NOT EXISTS %%I.%%I 
                     PARTITION OF %%I.fact_15min_stock_price 
                     FOR VALUES FROM (%%L) TO (%%L)'',
                    v_schema_name, partition_name, v_schema_name, start_val, end_val
                );

                current_m := next_m;
            END LOOP;

            EXECUTE FORMAT(
                ''CREATE TABLE IF NOT EXISTS %%I.fact_stock_default 
                 PARTITION OF %%I.fact_15min_stock_price DEFAULT'',
                v_schema_name, v_schema_name
            );
        END; $BODY$;', v_schema_name, v_schema_name);

END $$;