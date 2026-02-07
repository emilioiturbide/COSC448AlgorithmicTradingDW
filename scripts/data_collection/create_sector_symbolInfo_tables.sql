-- Original author: Justin Drenka
-- Source: https://github.com/youry/AlgorithmicTradingPublic
-- License: MIT
-- Modified by: Emilio Iturbide - 02/05/2026
-- Modifications: Created sector and symbol info tables with audit columns.

CREATE SCHEMA IF NOT EXISTS market;

CREATE TABLE IF NOT EXISTS market.Sectors (
    symbol VARCHAR(10) PRIMARY KEY,
    sector VARCHAR(50),
    _source_name VARCHAR(255),
    _source_filename VARCHAR(255),
    _loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

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
    ipo_date VARCHAR(50),
    is_active VARCHAR(10),
    _source_name VARCHAR(255),
    _source_filename VARCHAR(255),
    _loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);