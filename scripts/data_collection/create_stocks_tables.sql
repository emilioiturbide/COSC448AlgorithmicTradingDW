-- ================================================================================================
-- Script: create_stocks_tables.sql

-- Purpose:
-- This SQL script creates tables for storing stock price data for a predefined list of stock tickers.
-- Each table is named after the stock ticker and includes columns for date, open, high, low, close, 
--      volume, and audit information.

-- Intended Use:
-- This script is designed to be run once to set up the necessary tables for storing stock price data. 
--      It can be modified to include additional tickers or to change the structure of the tables as needed.

-- Usage:
-- 1. Run this script in your PostgreSQL database to create the tables for each stock ticker.
-- 2. Use these tables to store historical stock price data, which can then be used for analysis, 
--      reporting, or feeding into a data warehouse.

-- Output:
-- - A set of tables in the 'market' schema, each named after a stock ticker, with columns for 
--      stock price data and audit information.

-- Author: Justin Drenka
-- Original Script Name: 511TableCreationScript.sql
-- Source: https://github.com/youry/AlgorithmicTradingPublic
-- License: MIT
-- Modified by: Emilio Iturbide - 02/05/2026
-- Modifications: Updated db setup script to drop existing tables before creating new ones, 
--      added audit columns to landing tables.
-- ================================================================================================

-- Updated db setup script
CREATE SCHEMA IF NOT EXISTS market;

DO $$
DECLARE
    tickers text[] := ARRAY[
        'A','AAPL','ABBV','ABNB','ABT','ACGL','ACN','ADBE','ADI','ADM','ADP','ADSK','AEE','AEP',
        'AES','AFL','AIG','AIZ','AJG','AKAM','ALB','ALGN','ALL','ALLE','AMAT','AMCR','AMD','AME',
        'AMGN','AMP','AMT','AMZN','ANET','AON','AOS','APA','APD','APH','APO','APP','APTV','ARE',
        'ATO','AVB','AVGO','AVY','AWK','AXON','AXP','AZO','BA','BABA','BAC','BALL','BAX','BBY','BEN',
        'BDX','BF_B','BG','BIIB','BK','BKNG','BKR','BLDR','BLK','BMY','BR','BRK_B','BRO','BSX','BX',
        'BXP','C','CAG','CAH','CARR','CAT','CB','CBOE','CBRE','CCI','CCL','CDNS','CDW','CEG','CF',
        'CFG','CHD','CHRW','CHTR','CI','CINF','CL','CLX','CMCSA','CME','CMG','CMI','CMS','CNC','CNP',
        'COF','COIN','COO','COP','COR','COST','CPAY','CPB','CPRT','CPT','CRL','CRM','CRWD','CSCO',
        'CSGP','CSX','CTAS','CTRA','CTSH','CTVA','CVS','CVX','D','DAL','DASH','DAY','DD','DDOG','DE',
        'DECK','DELL','DG','DGX','DHI','DHR','DIS','DLR','DLTR','DOC','DOV','DOW','DPZ','DRI','DTE',
        'DUK','DVA','DVN','DXCM','EA','EBAY','ECL','ED','EFX','EG','EIX','EL','ELV','EME','EMN','EMR',
        'EOG','EPAM','EQIX','EQR','EQT','ERIE','ES','ESS','ETN','ETR','EVRG','EW','EXC','EXE','EXPD',
        'EXPE','EXR','F','FANG','FAST','FCX','FDS','FDX','FE','FFIV','FISV','FICO','FITB','FIS','FOX',
        'FOXA','FRT','FSLR','FTNT','FTV','GD','GDDY','GE','GEHC','GEN','GEV','GILD','GIS','GL','GLW',
        'GM','GNRC','GOOGL','GPC','GPN','GRMN','GS','GWW','HAL','HAS','HBAN','HCA','HD','HIG','HII',
        'HLT','HOLX','HON','HOOD','HPE','HPQ','HRL','HSIC','HST','HSY','HUBB','HUM','HWM','IBKR','IBM',
        'ICE','IDXX','IEX','IFF','INCY','INTC','INTU','INVH','IP','IPG','IQV','IR','IRM','ISRG','IT',
        'ITW','IVZ','J','JBHT','JBL','JCI','JKHY','JNJ','JPM','K','KDP','KEY','KEYS','KHC','KIM','KMB',
        'KMI','KMX','KKR','KLAC','KO','KR','KVUE','L','LDOS','LEN','LH','LHX','LII','LIN','LKQ','LLY',
        'LMT','LNT','LOW','LRCX','LULU','LUV','LW','LVS','LYB','LYV','MA','MAA','MAR','MAS','MCD',
        'MCHP','MCK','MCO','MDLZ','MDT','MET','META','MGM','MHK','MKC','MLM','MMC','MMM','MNST','MO',
        'MOH','MOS','MPC','MPWR','MRNA','MRK','MS','MSCI','MSFT','MSI','MTB','MTCH','MTD','MU','NCLH',
        'NDAQ','NDSN','NEE','NEM','NFLX','NI','NKE','NOC','NOW','NRG','NSC','NTAP','NTRS','NUE','NVDA',
        'NVR','NWS','NWSA','NXPI','O','ODFL','OKE','OMC','ON','ORCL','ORLY','OTIS','OXY','PANW','PAYC',
        'PAYX','PCAR','PCG','PEG','PEP','PFE','PFG','PG','PGR','PH','PHM','PKG','PLD','PLTR','PM','PNC',
        'PNR','PNW','PODD','POOL','PPG','PPL','PRU','PSA','PSKY','PSX','PTC','PWR','PYPL','QCOM','RCL',
        'REG','REGN','RF','RJF','RL','RMD','ROK','ROL','ROP','ROST','RSG','RTX','RVTY','SBAC','SBUX',
        'SCHW','SHW','SJM','SLB','SMCI','SNA','SNPS','SO','SOLV','SPG','SPGI','SRE','STE','STLD','STT',
        'STX','STZ','SW','SWK','SWKS','SYF','SYK','SYY','T','TAP','TDG','TDY','TECH','TEL','TER','TFC',
        'TGT','TJX','TKO','TMO','TMUS','TPL','TPR','TRGP','TRMB','TROW','TRV','TSCO','TSLA','TSN','TT',
        'TTD','TTWO','TXN','TXT','TYL','UAL','UBER','UDR','UHS','ULTA','UNH','UNP','UPS','URI','USB','V',
        'VICI','VLO','VLTO','VMC','VRSK','VRSN','VRTX','VST','VTR','VTRS','VZ','WAB','WAT','WBD','WDAY',
        'WDC','WEC','WELL','WFC','WM','WMB','WMT','WRB','WSM','WST','WTW','WY','WYNN','XEL','XOM','XYL',
        'XYZ','YUM','ZBH','ZBRA','ZTS', /* Bonds, Indices, Commodities -->*/ 'IRX', 'FVX', 'TNX', 'DJI',
        'IXIC', 'GSPC', 'GCF', 'CLF'
    ];
    sym text;
    tbl text;
BEGIN
    -- Drop all existing market tables safely
    RAISE NOTICE 'Dropping existing tables...';
    FOR sym IN SELECT table_name FROM information_schema.tables WHERE table_schema = 'market' LOOP
        EXECUTE format('DROP TABLE IF EXISTS market.%I CASCADE;', sym);
    END LOOP;

    -- =================================================================================================
    -- Modified by Emilio Iturbide - 02/05/2026
    -- Modifications: Added audit columns to landing tables and recreated tables for all tickers.
    -- =================================================================================================
    
    -- Recreate tables for all tickers
    FOREACH sym IN ARRAY tickers LOOP
        -- Format table name by removing special characters and converting to lower case
        tbl := lower(regexp_replace(sym, '[^A-Za-z0-9]', '', 'g'));
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS market.%I (
                stock_id bigserial PRIMARY KEY,
                date VARCHAR(50),
                open VARCHAR(50),
                high VARCHAR(50),
                low VARCHAR(50),
                close VARCHAR(50),
                volume VARCHAR(50),
                _source_name VARCHAR(255),
                _source_filename VARCHAR(255),
                _loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );', tbl);
    END LOOP;

    RAISE NOTICE 'All market tables recreated successfully.';
END $$;