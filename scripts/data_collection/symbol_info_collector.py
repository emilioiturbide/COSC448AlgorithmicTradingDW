# This script collects a list of stock symbol information from the FMP API
import requests
import psycopg2
from time import sleep

API_KEY = "7iSiCJecOuzJYx5xQr61Xd0f8NgNOnsU"  # Replace with your actual API key
POSTGRES_CONNECTION_PARAMS = {
    'host': 'localhost',
    'port': 15432,
    'database': 'emilioig_db',
    'user': 'emilioig',
    'password': 'Emitgo_03'
}

def fetch_stock_symbols():
    url = "https://financialmodelingprep.com/stable/profile?"

    symbols_list = ['A','AAPL','ABBV','ABNB','ABT','ACGL','ACN','ADBE','ADI','ADM','ADP','ADSK','AEE','AEP','AES','AFL','AIG','AIZ','AJG','AKAM','ALB','ALGN','ALL','ALLE','AMAT','AMCR','AMD','AME','AMGN','AMP','AMT','AMZN','ANET','AON','AOS','APA','APD','APH','APO','APP','APTV','ARE','ATO','AVB','AVGO','AVY','AWK','AXON','AXP','AZO','BA','BABA','BAC','BALL','BAX','BBY','BEN','BDX','BF_B','BG','BIIB','BK','BKNG','BKR','BLDR','BLK','BMY','BR','BRK_B','BRO','BSX','BX','BXP','C','CAG','CAH','CARR','CAT','CB','CBOE','CBRE','CCI','CCL','CDNS','CDW','CEG','CF','CFG','CHD','CHRW','CHTR','CI','CINF','CL','CLX','CMCSA','CME','CMG','CMI','CMS','CNC','CNP','COF','COIN','COO','COP','COR','COST','CPAY','CPB','CPRT','CPT','CRL','CRM','CRWD','CSCO','CSGP','CSX','CTAS','CTRA','CTSH','CTVA','CVS','CVX','D','DAL','DASH','DAY','DD','DDOG','DE','DECK','DELL','DG','DGX','DHI','DHR','DIS','DLR','DLTR','DOC','DOV','DOW','DPZ','DRI','DTE','DUK','DVA','DVN','DXCM','EA','EBAY','ECL','ED','EFX','EG','EIX','EL','ELV','EME','EMN','EMR','EOG','EPAM','EQIX','EQR','EQT','ERIE','ES','ESS','ETN','ETR','EVRG','EW','EXC','EXE','EXPD','EXPE','EXR','F','FANG','FAST','FCX','FDS','FDX','FE','FFIV','FISV','FICO','FITB','FIS','FOX','FOXA','FRT','FSLR','FTNT','FTV','GD','GDDY','GE','GEHC','GEN','GEV','GILD','GIS','GL','GLW','GM','GNRC','GOOGL','GPC','GPN','GRMN','GS','GWW','HAL','HAS','HBAN','HCA','HD','HIG','HII','HLT','HOLX','HON','HOOD','HPE','HPQ','HRL','HSIC','HST','HSY','HUBB','HUM','HWM','IBKR','IBM','ICE','IDXX','IEX','IFF','INCY','INTC','INTU','INVH','IP','IPG','IQV','IR','IRM','ISRG','IT','ITW','IVZ','J','JBHT','JBL','JCI','JKHY','JNJ','JPM','K','KDP','KEY','KEYS','KHC','KIM','KMB','KMI','KMX','KKR','KLAC','KO','KR','KVUE','L','LDOS','LEN','LH','LHX','LII','LIN','LKQ','LLY','LMT','LNT','LOW','LRCX','LULU','LUV','LW','LVS','LYB','LYV','MA','MAA','MAR','MAS','MCD','MCHP','MCK','MCO','MDLZ','MDT','MET','META','MGM','MHK','MKC','MLM','MMC','MMM','MNST','MO','MOH','MOS','MPC','MPWR','MRNA','MRK','MS','MSCI','MSFT','MSI','MTB','MTCH','MTD','MU','NCLH','NDAQ','NDSN','NEE','NEM','NFLX','NI','NKE','NOC','NOW','NRG','NSC','NTAP','NTRS','NUE','NVDA','NVR','NWS','NWSA','NXPI','O','ODFL','OKE','OMC','ON','ORCL','ORLY','OTIS','OXY','PANW','PAYC','PAYX','PCAR','PCG','PEG','PEP','PFE','PFG','PG','PGR','PH','PHM','PKG','PLD','PLTR','PM','PNC','PNR','PNW','PODD','POOL','PPG','PPL','PRU','PSA','PSKY','PSX','PTC','PWR','PYPL','QCOM','RCL','REG','REGN','RF','RJF','RL','RMD','ROK','ROL','ROP','ROST','RSG','RTX','RVTY','SBAC','SBUX','SCHW','SHW','SJM','SLB','SMCI','SNA','SNPS','SO','SOLV','SPG','SPGI','SRE','STE','STLD','STT','STX','STZ','SW','SWK','SWKS','SYF','SYK','SYY','T','TAP','TDG','TDY','TECH','TEL','TER','TFC','TGT','TJX','TKO','TMO','TMUS','TPL','TPR','TRGP','TRMB','TROW','TRV','TSCO','TSLA','TSN','TT','TTD','TTWO','TXN','TXT','TYL','UAL','UBER','UDR','UHS','ULTA','UNH','UNP','UPS','URI','USB','V','VICI','VLO','VLTO','VMC','VRSK','VRSN','VRTX','VST','VTR','VTRS','VZ','WAB','WAT','WBD','WDAY','WDC','WEC','WELL','WFC','WM','WMB','WMT','WRB','WSM','WST','WTW','WY','WYNN','XEL','XOM','XYL','XYZ','YUM','ZBH','ZBRA','ZTS'
                ]
    
    # split symbols_list into chunks of 50 to avoid URL length issues
    stock_data = []
    for i in range(0, len(symbols_list), 50):
        chunk = symbols_list[i:i + 50]
        chunk_data = collect_symbol_data(chunk, url)
        # API rate limit is 300 requests per minute
        sleep(30)
        stock_data.extend(chunk_data)
    return stock_data

def collect_symbol_data(symbols_list, url):
    
    # Collect profile data for each symbol and store in db
    stock_data = []
    for symbol in symbols_list:
        print(f"Fetching data for symbol: {symbol}")
        symbol = symbol.replace('_', '-')
        response = requests.get(url + f"symbol={symbol}&apikey={API_KEY}")
        if response.status_code == 200:
            print(f"Successfully fetched data for symbol: {symbol}")
            data = response.json()
            if data:
                profile = data[0]
                stock_data.append({
                    'symbol': profile.get('symbol'),
                    'companyName': profile.get('companyName'),
                    'exchange': profile.get('exchange'),
                    'exchangeFullName' : profile.get('exchangeFullName'),
                    'industry': profile.get('industry'),
                    'currency': profile.get('currency'),
                    'website': profile.get('website'),
                    'description': profile.get('description'),
                    'ceo': profile.get('ceo'),
                    'sector': profile.get('sector'),
                    'country': profile.get('country'),
                    'fullTimeEmployees': profile.get('fullTimeEmployees'),
                    'ipoDate': profile.get('ipoDate'),
                    'isActivelyTrading': profile.get('isActivelyTrading'),
                    '_source_name': 'API Import',
                    '_source_filename': f'{url}'
                })
        else:
            print(f"Failed to fetch data for symbol: {symbol}")
    return stock_data
def insert_stock_symbols_to_db(stock_data):
    # Connect to the PostgreSQL database
    print("Connecting to the database...")
    conn = psycopg2.connect(**POSTGRES_CONNECTION_PARAMS)
    cursor = conn.cursor()
    print("Inserting stock symbol data into the database...")

    # Insert stock symbol data into the database
    for stock in stock_data:
        cursor.execute("""
            INSERT INTO market.symbol_info (symbol, company_name, exchange, exchange_full_name, industry, currency, website, description, ceo, sector, country, full_time_employees, ipo_date, is_active, _source_name, _source_filename)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            stock['symbol'],
            stock['companyName'],
            stock['exchange'],
            stock['exchangeFullName'],
            stock['industry'],
            stock['currency'],
            stock['website'],
            stock['description'],
            stock['ceo'],
            stock['sector'],
            stock['country'],
            stock['fullTimeEmployees'],
            stock['ipoDate'],
            stock['isActivelyTrading'],
            stock['_source_name'],
            stock['_source_filename']
        ))
    conn.commit()
    cursor.close()
    conn.close()
    print("Stock symbol data insertion complete.")


def main():
    stock_data = fetch_stock_symbols()
    insert_stock_symbols_to_db(stock_data)

if __name__ == "__main__":
    main()