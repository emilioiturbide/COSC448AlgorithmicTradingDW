-- ================================================================================================
-- Script: data_validation.sql

-- Purpose:
-- This SQL script performs data validation and transformation on raw stock price data.
-- It creates views to cleanse and harden the data, and then inserts the validated data 
--  into a staging table for further processing.

-- Intended Use:
-- This script is designed to be run after raw stock price data has been loaded into 
--  the 'market' schema. It validates the data by checking for duplicates, missing values, 
--  and logical inconsistencies (e.g., high price should not be less than low price). 
-- The cleansed and validated data is then inserted into the 'core_staging.stg_stock_price' table, 
--  which serves as the source for further transformations and loading into the data warehouse.

-- Usage:
-- 1. Ensure that raw stock price data is loaded into the 'market' schema with 
--    appropriate table names (e.g., 'market.stg_1_stock_data_aapl' for AAPL).
-- 2. Run this script to create views for each stock symbol that perform data validation and cleansing.
-- 3. The validated data will be inserted into the 'core_staging.stg_stock_price' staging table, 
--  which can then be used for further transformations or loading into the data warehouse.

-- Output:
-- - Views in the 'market' schema for each stock symbol that perform data validation and cleansing.
-- - A populated 'core_staging.stg_stock_price' table containing cleansed and validated 
--   stock price data ready for further processing.

-- Author: Emilio Iturbide Gonzalez
-- License: MIT
-- ================================================================================================

DO $$
DECLARE
    symbols_list text[] := ARRAY[
        'A','AAPL','ABBV','ABNB','ABT','ACGL','ACN','ADBE','ADI','ADM','ADP','ADSK',
        'AEE','AEP','AES','AFL','AIG','AIZ','AJG','AKAM','ALB','ALGN','ALL','ALLE','AMAT',
        'AMCR','AMD','AME','AMGN','AMP','AMT','AMZN','ANET','AON','AOS','APA','APD','APH','APO',
        'APP','APTV','ARE','ATO','AVB','AVGO','AVY','AWK','AXON','AXP','AZO','BA','BABA','BAC',
        'BALL','BAX','BBY','BEN','BDX','BF_B','BG','BIIB','BK','BKNG','BKR','BLDR','BLK','BMY','BR',
        'BRK_B','BRO','BSX','BX','BXP','C','CAG','CAH','CARR','CAT','CB','CBOE','CBRE','CCI','CCL',
        'CDNS','CDW','CEG','CF','CFG','CHD','CHRW','CHTR','CI','CINF','CL','CLX','CMCSA','CME','CMG',
        'CMI','CMS','CNC','CNP','COF','COIN','COO','COP','COR','COST','CPAY','CPB','CPRT','CPT','CRL',
        'CRM','CRWD','CSCO','CSGP','CSX','CTAS','CTRA','CTSH','CTVA','CVS','CVX','D','DAL','DASH','DAY',
        'DD','DDOG','DE','DECK','DELL','DG','DGX','DHI','DHR','DIS','DLR','DLTR','DOC','DOV','DOW','DPZ',
        'DRI','DTE','DUK','DVA','DVN','DXCM','EA','EBAY','ECL','ED','EFX','EG','EIX','EL','ELV','EME',
        'EMN','EMR','EOG','EPAM','EQIX','EQR','EQT','ERIE','ES','ESS','ETN','ETR','EVRG','EW','EXC','EXE',
        'EXPD','EXPE','EXR','F','FANG','FAST','FCX','FDS','FDX','FE','FFIV','FISV','FICO','FITB','FIS',
        'FOX','FOXA','FRT','FSLR','FTNT','FTV','GD','GDDY','GE','GEHC','GEN','GEV','GILD','GIS','GL','GLW',
        'GM','GNRC','GOOGL','GPC','GPN','GRMN','GS','GWW','HAL','HAS','HBAN','HCA','HD','HIG','HII','HLT',
        'HOLX','HON','HOOD','HPE','HPQ','HRL','HSIC','HST','HSY','HUBB','HUM','HWM','IBKR','IBM','ICE',
        'IDXX','IEX','IFF','INCY','INTC','INTU','INVH','IP','IPG','IQV','IR','IRM','ISRG','IT','ITW','IVZ',
        'J','JBHT','JBL','JCI','JKHY','JNJ','JPM','K','KDP','KEY','KEYS','KHC','KIM','KMB','KMI','KMX',
        'KKR','KLAC','KO','KR','KVUE','L','LDOS','LEN','LH','LHX','LII','LIN','LKQ','LLY','LMT','LNT','LOW',
        'LRCX','LULU','LUV','LW','LVS','LYB','LYV','MA','MAA','MAR','MAS','MCD','MCHP','MCK','MCO','MDLZ',
        'MDT','MET','META','MGM','MHK','MKC','MLM','MMC','MMM','MNST','MO','MOH','MOS','MPC','MPWR','MRNA',
        'MRK','MS','MSCI','MSFT','MSI','MTB','MTCH','MTD','MU','NCLH','NDAQ','NDSN','NEE','NEM','NFLX','NI',
        'NKE','NOC','NOW','NRG','NSC','NTAP','NTRS','NUE','NVDA','NVR','NWS','NWSA','NXPI','O','ODFL','OKE',
        'OMC','ON','ORCL','ORLY','OTIS','OXY','PANW','PAYC','PAYX','PCAR','PCG','PEG','PEP','PFE','PFG','PG',
        'PGR','PH','PHM','PKG','PLD','PLTR','PM','PNC','PNR','PNW','PODD','POOL','PPG','PPL','PRU','PSA',
        'PSKY','PSX','PTC','PWR','PYPL','QCOM','RCL','REG','REGN','RF','RJF','RL','RMD','ROK','ROL','ROP',
        'ROST','RSG','RTX','RVTY','SBAC','SBUX','SCHW','SHW','SJM','SLB','SMCI','SNA','SNPS','SO','SOLV',
        'SPG','SPGI','SRE','STE','STLD','STT','STX','STZ','SW','SWK','SWKS','SYF','SYK','SYY','T','TAP','TDG',
        'TDY','TECH','TEL','TER','TFC','TGT','TJX','TKO','TMO','TMUS','TPL','TPR','TRGP','TRMB','TROW','TRV',
        'TSCO','TSLA','TSN','TT','TTD','TTWO','TXN','TXT','TYL','UAL','UBER','UDR','UHS','ULTA','UNH','UNP',
        'UPS','URI','USB','V','VICI','VLO','VLTO','VMC','VRSK','VRSN','VRTX','VST','VTR','VTRS','VZ','WAB',
        'WAT','WBD','WDAY','WDC','WEC','WELL','WFC','WM','WMB','WMT','WRB','WSM','WST','WTW','WY','WYNN',
        'XEL','XOM','XYL','XYZ','YUM','ZBH','ZBRA','ZTS', 
        /* Bonds, Indices, Commodities -->*/ 'IRX', 'FVX', 'TNX', 'DJI', 'IXIC', 'GSPC', 'GCF', 'CLF'
    ];
    bonds_list text[] := ARRAY['IRX', 'FVX', 'TNX'];
    indices_list text[] := ARRAY['DJI', 'IXIC', 'GSPC'];
    commodities_list text[] := ARRAY['GCF', 'CLF'];
    sql_stmt TEXT;
    formatted_symbol TEXT;
    symbol_type TEXT;
    v_timezone TEXT = 'America/New_York';

BEGIN
    -- =================================================================================
    -- Create schema for staging tables if it doesn't exist.
    -- This schema will hold the staging tables that are used for data validation and 
    --  transformation before loading into the data warehouse.
    -- =================================================================================
    RAISE NOTICE 'Creating staging schema and tables if they do not exist...';
    CREATE SCHEMA IF NOT EXISTS core_staging;
    CREATE TABLE IF NOT EXISTS core_staging.stg_stock_price (
        stock_id bigserial PRIMARY KEY,
        ticker_symbol VARCHAR(10),
        trade_date TIMESTAMP,
        timezone VARCHAR(50),
        open_price DECIMAL(18, 6),
        high_price DECIMAL(18, 6),
        low_price DECIMAL(18, 6),
        close_price DECIMAL(18, 6),
        volume BIGINT,
        symbol_type VARCHAR(20),
        _source_name VARCHAR(255),
        _source_filename VARCHAR(255),
        _is_cleansed BOOLEAN,
        _is_duplicate BOOLEAN,
        _audit_hash VARCHAR(64)
    );
    RAISE NOTICE 'Staging schema and tables created successfully.';

    -- =================================================================================
    -- Loop through the list of symbols and create views for each symbol to perform 
    --  data validation and cleansing.
    -- 'symbol' in table name is formatted without '_', '.', or '-' to avoid issues 
    --      with view naming conventions and in lower case.
    -- The views will perform the following transformations:
    -- 1. Convert date to timestamp and trim whitespace.
    -- 2. Convert price fields to decimal and handle empty strings as NULL.
    -- 3. Convert volume to bigint and handle cases where volume is in format '2.0' 
    --      by splitting on the decimal point.
    -- 4. Add symbol type based on predefined lists of bonds, indices, and commodities.
    -- 5. Add flags for duplicates and cleansing based on the presence of nulls, 
    --      negative values, and logical inconsistencies.
    -- 6. Create an audit hash by concatenating symbol, date, and close price to 
    --      create a unique identifier for auditing purposes.
    -- 7. Add transformation version for tracking changes in the transformation 
    --      logic over time.
    -- =================================================================================
    FOR i IN 1..array_length(symbols_list, 1) LOOP
        RAISE NOTICE 'Processing symbol: %', symbols_list[i];
        IF symbols_list[i] = ANY(bonds_list) THEN
            symbol_type := 'bond';
        ELSIF symbols_list[i] = ANY(indices_list) THEN
            symbol_type := 'index';
        ELSIF symbols_list[i] = ANY(commodities_list) THEN
            symbol_type := 'commodity';
        ELSE
            symbol_type := 'stock';
        END IF;
        formatted_symbol := LOWER(REPLACE(REPLACE(REPLACE(symbols_list[i], '_', ''), '.', ''), '-', ''));
        sql_stmt := format($f$
            DROP VIEW IF EXISTS market.%1$I CASCADE;
            CREATE OR REPLACE VIEW market.%1$I AS
            SELECT DISTINCT ON (date::Timestamp)
                -- =============================================================================
                -- Transform data to fit staging table schema
                -- ==============================================================================
                %2$L::VARCHAR(10) AS ticker_symbol,
                UPPER(TRIM(date))::TIMESTAMP AS trade_date,
                %5$L::VARCHAR(50) AS timezone,
                NULLIF(open, '')::DECIMAL(18, 6) AS open_price,
                NULLIF(high, '')::DECIMAL(18, 6) AS high_price,
                NULLIF(low, '')::DECIMAL(18, 6) AS low_price,
                NULLIF(close, '')::DECIMAL(18, 6) AS close_price,
                -- =============================================================================
                -- If volume is in format 2.0, get rid of anything after decimal point
                -- =============================================================================
                CASE 
                    WHEN POSITION('.' IN TRIM(volume)) > 0 THEN
                        SPLIT_PART(TRIM(volume), '.', 1)::BIGINT
                    ELSE
                        NULLIF(TRIM(volume), '')::BIGINT
                END AS volume,
                %3$L::VARCHAR(20) AS symbol_type,
                _source_name,
                _source_filename,
                -- ============================================================================
                -- _is_duplicate flag to identify duplicate records based on symbol and date
                -- ============================================================================
                CASE 
                    WHEN COUNT(*) OVER (PARTITION BY TRIM(date)) > 1 THEN TRUE ELSE FALSE END AS _is_duplicate,
                -- ============================================================================
                -- Concatenate symbol, date, and close price to create a unique hash for auditing
                -- ============================================================================
                MD5(CONCAT(%2$L, TRIM(date), NULLIF(close, ''))) AS _audit_hash,

                -- ============================================================================
                -- Transformation version is added to track changes in the transformation logic over time. 
                --  This allows us to identify which version of the transformation logic 
                --  was applied to each record, which is important for auditing and debugging purposes. 
                --  If we need to make changes to the transformation logic in the future, 
                --  we can simply update the transformation version and create new views with 
                --  the updated logic while keeping the old views intact for historical reference.
                -- ============================================================================
                'v1.0' AS _transformation_version

            FROM market.%4$I
            ORDER BY date::Timestamp DESC;
        $f$, 'stg_1_stock_data_' || formatted_symbol, symbols_list[i], symbol_type, formatted_symbol, v_timezone);
        RAISE NOTICE 'Creating view for symbol: %', symbols_list[i];
        EXECUTE sql_stmt;

        -- ================================================================================
        -- Create new view for cleansed and hardened data with additional flags for 
        --  cleansing and duplicates based on the first view. This view will be used 
        --  for loading into the staging table.
        -- The view will perform the following transformations:
        -- 1. Add a flag for duplicates based on the presence of multiple records for the same date.
        -- 2. Add a flag for cleansing based on the presence of nulls, negative values, 
        --    and logical inconsistencies (e.g., high price should not be less than low price).
        -- 3. Keep the transformation version for tracking changes in the transformation logic over time.
        -- ================================================================================
        sql_stmt := format($f$
            DROP VIEW IF EXISTS market.%1$I CASCADE;
            CREATE OR REPLACE VIEW market.%1$I AS
            SELECT ticker_symbol,
                trade_date,
                timezone,
                open_price,
                high_price,
                low_price,
                close_price,
                volume,
                symbol_type,
                _source_name,
                _source_filename,
                _audit_hash,
                CASE
                    WHEN COUNT(*) OVER (PARTITION BY trade_date) > 1 THEN TRUE
                    ELSE FALSE
                END AS _is_duplicate,
                CASE
                    WHEN open_price IS NULL
                            OR trade_date IS NULL
                            OR close_price IS NULL
                            OR volume IS NULL
                            OR high_price IS NULL
                            OR low_price IS NULL THEN TRUE
                    WHEN open_price < 0
                            OR high_price < 0
                            OR low_price < 0
                            OR close_price < 0
                            OR volume < 0 THEN TRUE
                    WHEN high_price < low_price THEN TRUE
                    ELSE FALSE
                END AS _is_cleansed,
                'v2.0' AS _transformation_version

            FROM market.%2$I;
        $f$, 'stg_2_stock_data_' || formatted_symbol, 'stg_1_stock_data_' || formatted_symbol);
        RAISE NOTICE 'Creating second view for symbol: %', symbols_list[i];
        EXECUTE sql_stmt;

        -- ================================================================================
        -- If the second view creation is successful, add the content of the view 
        --      to the stg_stock_price staging table for loading into the data warehouse.
        -- ================================================================================
        sql_stmt := format($f$
            INSERT INTO core_staging.stg_stock_price (
                ticker_symbol,
                trade_date,
                timezone,
                open_price,
                high_price,
                low_price,
                close_price,
                volume,
                symbol_type,
                _source_name,
                _source_filename,
                _is_cleansed,
                _is_duplicate,
                _audit_hash
            )
            SELECT 
                ticker_symbol,
                trade_date,
                timezone,
                open_price,
                high_price,
                low_price,
                close_price,
                volume,
                symbol_type,
                _source_name,
                _source_filename,
                _is_cleansed,
                _is_duplicate,
                _audit_hash
            FROM market.%1$I;
        $f$, 'stg_2_stock_data_' || formatted_symbol);
        RAISE NOTICE 'Inserting data into staging table for symbol: %', symbols_list[i];
        EXECUTE sql_stmt;
        RAISE NOTICE 'Data inserted into staging table for symbol: %', symbols_list[i];
        RAISE NOTICE 'Dropping intermediate views for symbol: %', symbols_list[i];
        -- ================================================================================
        -- Drop intermediate views to save space
        -- ================================================================================
        sql_stmt := format($f$
            DROP VIEW IF EXISTS market.%1$I CASCADE;
        $f$, 'stg_1_stock_data_' || formatted_symbol);
        EXECUTE sql_stmt;
        RAISE NOTICE 'Intermediate views dropped for symbol: %', symbols_list[i];
        formatted_symbol := '';
    END LOOP;

    -- =================================================================================
    -- Validate symbol_info table
    -- Create a view for symbol_info that selects the most recent record for each symbol
    --  based on the _loaded_at timestamp. This will ensure that we have the most 
    --  up-to-date information for each symbol when we load it into the staging table.
    -- =================================================================================
    RAISE NOTICE 'Validating symbol_info table...';
    CREATE OR REPLACE VIEW market.vw_symbol_info AS
    SELECT DISTINCT ON (symbol)
            symbol,
            company_name,
            ceo,
            currency,
            sector,
            industry,
            full_time_employees::integer AS full_time_employees,
            country,
            state,
            city,
            zip,
            address,
            exchange,
            exchange_full_name,
            ipo_date::date AS ipo_date,
            is_active::boolean AS is_active,
            is_etf::boolean AS is_etf,
            is_fund::boolean AS is_fund,
            _source_name,
            _source_filename,
            _loaded_at
    FROM market.symbol_info
    ORDER BY symbol, _loaded_at DESC;
    RAISE NOTICE 'symbol_info view created successfully.';
    RAISE NOTICE 'Inserting data into core_staging.stg_companies';

    -- ================================================================================
    -- Insert data into staging table for companies from the symbol_info view
    -- This will allow us to have a cleansed and validated list of companies with their 
    --  associated metadata for use in the data warehouse.
    -- ================================================================================
    CREATE TABLE IF NOT EXISTS core_staging.stg_companies AS
    SELECT * FROM market.vw_symbol_info;

    RAISE NOTICE 'Data inserted into core_staging.stg_companies successfully.';

    RAISE NOTICE 'Data validation completed successfully.';
END $$;