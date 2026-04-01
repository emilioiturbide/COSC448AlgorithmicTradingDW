-- ================================================================================
-- Script: create_sector_symbolInfo_tables.sql

-- Purpose:
-- This SQL script creates two tables in the 'market' schema: 'Sectors'
--      and 'Symbol_Info'.
-- The 'Sectors' table stores the stock symbol and its corresponding sector, 
--      along with audit information.
-- The 'Symbol_Info' table stores detailed information about each stock symbol, 
--      including company name, exchange, industry, and other relevant attributes, 
--      along with audit information.

-- Intended Use:
-- This script is designed to be run once to set up the necessary tables for 
--      storing sector and symbol information.
-- It can be modified to include additional columns or to change the structure 
--      of the tables as needed.

-- Usage:
-- 1. Run this script in your PostgreSQL database to create the 'Sectors' and 
--      'Symbol_Info' tables in the 'market' schema.
-- 2. Use these tables to store sector and symbol information, which can then 
--      be used for analysis, reporting, or feeding into a data warehouse.

-- Output:
-- - Two tables in the 'market' schema: 'Sectors' and 'Symbol_Info', with columns 
--      for sector and symbol information, as well as audit information.

-- Author: Justin Drenka
-- Original Script Name: SectorTableCreationScript.sql
-- Source: https://github.com/youry/AlgorithmicTradingPublic
-- License: MIT
-- Modified by: Emilio Iturbide - 02/05/2026
-- Modifications: Created sector and symbol info tables with audit columns.
-- ================================================================================

CREATE SCHEMA IF NOT EXISTS market;

-- =================================================================================
-- Modified by Emilio Iturbide - 02/05/2026
-- Modifications: Added audit columns to sectors table.
-- =================================================================================
CREATE TABLE IF NOT EXISTS market.Sectors (
    symbol VARCHAR(10) PRIMARY KEY,
    sector VARCHAR(50),
    _source_name VARCHAR(255),
    _source_filename VARCHAR(255),
    _loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =================================================================================
-- Modified by Emilio Iturbide - 02/05/2026
-- Modifications: Created new table for symbol information with audit columns.
-- =================================================================================
CREATE TABLE IF NOT EXISTS market.Symbol_Info (
    symbol VARCHAR(10) PRIMARY KEY,
    company_name VARCHAR(255),
    exchange VARCHAR(100),
    exchange_full_name VARCHAR(255),
    industry VARCHAR(100),
    currency VARCHAR(10),
    website VARCHAR(255),
    description TEXT,
    ceo VARCHAR(100),
    sector VARCHAR(100),
    country VARCHAR(100),
    full_time_employees VARCHAR(50),
    city VARCHAR(100),
    state VARCHAR(100),
    zip VARCHAR(20),
    address VARCHAR(255),
    ipo_date VARCHAR(50),
    is_active VARCHAR(10),
    is_etf VARCHAR(10),
    is_fund VARCHAR(10),
    _source_name VARCHAR(255),
    _source_filename VARCHAR(255),
    _loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);