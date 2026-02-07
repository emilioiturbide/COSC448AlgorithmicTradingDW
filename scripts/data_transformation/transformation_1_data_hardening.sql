DO $$
DECLARE
symbols_list text[] := ARRAY['A','AAPL','ABBV','ABNB','ABT','ACGL','ACN','ADBE','ADI','ADM','ADP','ADSK','AEE','AEP','AES','AFL','AIG','AIZ','AJG','AKAM','ALB','ALGN','ALL','ALLE','AMAT','AMCR','AMD','AME','AMGN','AMP','AMT','AMZN','ANET','AON','AOS','APA','APD','APH','APO','APP','APTV','ARE','ATO','AVB','AVGO','AVY','AWK','AXON','AXP','AZO','BA','BABA','BAC','BALL','BAX','BBY','BEN','BDX','BF_B','BG','BIIB','BK','BKNG','BKR','BLDR','BLK','BMY','BR','BRK_B','BRO','BSX','BX','BXP','C','CAG','CAH','CARR','CAT','CB','CBOE','CBRE','CCI','CCL','CDNS','CDW','CEG','CF','CFG','CHD','CHRW','CHTR','CI','CINF','CL','CLX','CMCSA','CME','CMG','CMI','CMS','CNC','CNP','COF','COIN','COO','COP','COR','COST','CPAY','CPB','CPRT','CPT','CRL','CRM','CRWD','CSCO','CSGP','CSX','CTAS','CTRA','CTSH','CTVA','CVS','CVX','D','DAL','DASH','DAY','DD','DDOG','DE','DECK','DELL','DG','DGX','DHI','DHR','DIS','DLR','DLTR','DOC','DOV','DOW','DPZ','DRI','DTE','DUK','DVA','DVN','DXCM','EA','EBAY','ECL','ED','EFX','EG','EIX','EL','ELV','EME','EMN','EMR','EOG','EPAM','EQIX','EQR','EQT','ERIE','ES','ESS','ETN','ETR','EVRG','EW','EXC','EXE','EXPD','EXPE','EXR','F','FANG','FAST','FCX','FDS','FDX','FE','FFIV','FISV','FICO','FITB','FIS','FOX','FOXA','FRT','FSLR','FTNT','FTV','GD','GDDY','GE','GEHC','GEN','GEV','GILD','GIS','GL','GLW','GM','GNRC','GOOGL','GPC','GPN','GRMN','GS','GWW','HAL','HAS','HBAN','HCA','HD','HIG','HII','HLT','HOLX','HON','HOOD','HPE','HPQ','HRL','HSIC','HST','HSY','HUBB','HUM','HWM','IBKR','IBM','ICE','IDXX','IEX','IFF','INCY','INTC','INTU','INVH','IP','IPG','IQV','IR','IRM','ISRG','IT','ITW','IVZ','J','JBHT','JBL','JCI','JKHY','JNJ','JPM','K','KDP','KEY','KEYS','KHC','KIM','KMB','KMI','KMX','KKR','KLAC','KO','KR','KVUE','L','LDOS','LEN','LH','LHX','LII','LIN','LKQ','LLY','LMT','LNT','LOW','LRCX','LULU','LUV','LW','LVS','LYB','LYV','MA','MAA','MAR','MAS','MCD','MCHP','MCK','MCO','MDLZ','MDT','MET','META','MGM','MHK','MKC','MLM','MMC','MMM','MNST','MO','MOH','MOS','MPC','MPWR','MRNA','MRK','MS','MSCI','MSFT','MSI','MTB','MTCH','MTD','MU','NCLH','NDAQ','NDSN','NEE','NEM','NFLX','NI','NKE','NOC','NOW','NRG','NSC','NTAP','NTRS','NUE','NVDA','NVR','NWS','NWSA','NXPI','O','ODFL','OKE','OMC','ON','ORCL','ORLY','OTIS','OXY','PANW','PAYC','PAYX','PCAR','PCG','PEG','PEP','PFE','PFG','PG','PGR','PH','PHM','PKG','PLD','PLTR','PM','PNC','PNR','PNW','PODD','POOL','PPG','PPL','PRU','PSA','PSKY','PSX','PTC','PWR','PYPL','QCOM','RCL','REG','REGN','RF','RJF','RL','RMD','ROK','ROL','ROP','ROST','RSG','RTX','RVTY','SBAC','SBUX','SCHW','SHW','SJM','SLB','SMCI','SNA','SNPS','SO','SOLV','SPG','SPGI','SRE','STE','STLD','STT','STX','STZ','SW','SWK','SWKS','SYF','SYK','SYY','T','TAP','TDG','TDY','TECH','TEL','TER','TFC','TGT','TJX','TKO','TMO','TMUS','TPL','TPR','TRGP','TRMB','TROW','TRV','TSCO','TSLA','TSN','TT','TTD','TTWO','TXN','TXT','TYL','UAL','UBER','UDR','UHS','ULTA','UNH','UNP','UPS','URI','USB','V','VICI','VLO','VLTO','VMC','VRSK','VRSN','VRTX','VST','VTR','VTRS','VZ','WAB','WAT','WBD','WDAY','WDC','WEC','WELL','WFC','WM','WMB','WMT','WRB','WSM','WST','WTW','WY','WYNN','XEL','XOM','XYL','XYZ','YUM','ZBH','ZBRA','ZTS'
                ];

-- Declare sql statement variable as string
sql_stmt TEXT;
formatted_symbol TEXT;

BEGIN
-- symbol in table name is formatted without '_', '.', or '-' to avoid issues with view naming conventions and in lower case
FOR i IN 1..array_length(symbols_list, 1) LOOP
    formatted_symbol := LOWER(REPLACE(REPLACE(REPLACE(symbols_list[i], '_', ''), '.', ''), '-', ''));
    sql_stmt := format($f$
        DROP VIEW IF EXISTS market.%1$I;
        CREATE OR REPLACE VIEW market.%1$I AS
        SELECT DISTINCT ON (date::Timestamp)
            -- transform data to fit staging table schema
            %2$L::VARCHAR(10) AS ticker_symbol,
            UPPER(TRIM(date))::TIMESTAMP AS trade_date,
            NULLIF(open, '')::DECIMAL(18, 6) AS open_price,
            NULLIF(high, '')::DECIMAL(18, 6) AS high_price,
            NULLIF(low, '')::DECIMAL(18, 6) AS low_price,
            NULLIF(close, '')::DECIMAL(18, 6) AS close_price,
            -- if volume is in format 2.0, get rid of anything after decimal point
            CASE 
                WHEN POSITION('.' IN TRIM(volume)) > 0 THEN
                    SPLIT_PART(TRIM(volume), '.', 1)::BIGINT
                ELSE
                    NULLIF(TRIM(volume), '')::BIGINT
            END AS volume,
            _source_name,
            _source_filename,

            --CASE 
            --    WHEN open IS NULL OR date IS NULL OR close IS NULL OR volume IS NULL OR high IS NULL OR low IS NULL THEN TRUE 
            --    WHEN open::DECIMAL(18, 6) < 0 OR high::DECIMAL(18, 6) < 0 OR low::DECIMAL(18, 6) < 0 OR close::DECIMAL(18, 6) < 0 OR volume::BIGINT < 0 THEN TRUE
            --    WHEN high::DECIMAL(18, 6) < low::DECIMAL(18, 6) THEN TRUE
            --    ELSE FALSE
            --END AS _is_cleansed,

            -- _is_duplicate flag to identify duplicate records based on symbol and date
            CASE 
                WHEN COUNT(*) OVER (PARTITION BY TRIM(date)) > 1 THEN TRUE ELSE FALSE END AS _is_duplicate,
            --concatenate symbol, date, and close price to create a unique hash for auditing
            MD5(CONCAT(%2$L, TRIM(date), NULLIF(close, ''))) AS _audit_hash,

            -- transformation version
            'v1.0' AS _transformation_version

        FROM market.%3$I
        ORDER BY date::Timestamp DESC;
    $f$, 'stg_1_stock_data_' || formatted_symbol, symbols_list[i], formatted_symbol);
    
    EXECUTE sql_stmt;
    formatted_symbol := '';
END LOOP;
END $$;

-- SELECT * FROM market.stg_1_stock_data_gis;