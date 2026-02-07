# Original author: Justin Drenka
# Source: https://github.com/youry/AlgorithmicTradingPublic
# License: MIT
# Modified by: Emilio Iturbide - 02/05/2026
# Modifications: Updated connection parameters, 
#               removed casting sections to ensure data would land correctly in the DB,
#               added additional audit columns to the staging tables,

#we created 503 stock tables, and a sector table before running this script 
import psycopg2
import pandas as pd
import os
import glob
from io import StringIO

CONNECTION_PARAMS = {
    'host': 'localhost',
    'port': 15432,
    'database': 'emilioig_db',
    'user': 'emilioig',
    'password': 'Emitgo_03'
}
def main():
    # Connect to localhost:15432 (the tunnel endpoint)
    conn = psycopg2.connect(**CONNECTION_PARAMS)
    #Insertion Code
    # 503 stock CSV files
    #csvStockDirectory = "./input/503_Stocks/"
    # 29 stock CSV files
    csvStockDirectory = "../../input/29_Stocks/"
    csv_files = glob.glob(os.path.join(csvStockDirectory, "*.csv")) # get all csv files in directory
    csv_filenames = [os.path.basename(file) for file in csv_files]
    cursor = conn.cursor()
    logFile = open("../../output/RawInsertLog.txt", "a")
    for i in range(len(csv_files)):
        try:
            # Read CSV and clean data
            print(csvStockDirectory + csv_filenames[i])
            currentDataFrame = pd.read_csv(csvStockDirectory + csv_filenames[i])
            currentBaseName = os.path.splitext(csv_filenames[i])[0].lower()
            # replace '.' with '' to match table naming convention
            currentBaseName = currentBaseName.replace('.', '')
            print(f"Now inserting into {currentBaseName}: ", csv_filenames[i])
            logFile.write(currentBaseName + ":\n")

            # add _source and _source_filename columns
            currentDataFrame['_source_name'] = 'CSV Import'
            currentDataFrame['_source_filename'] = csv_filenames[i]
            currentDataFrame = currentDataFrame.filter(['date', 'open', 'high', 'low', 'close', 'volume', '_source_name', '_source_filename'])
            # Use COPY for bulk insertion
            buffer = StringIO()
            currentDataFrame.to_csv(buffer, index=False, header=False)
            buffer.seek(0)
            print("reached before")
            copy_sql = f"COPY market.{currentBaseName} (date, open, high, low, close, volume, _source_name, _source_filename) FROM STDIN WITH CSV"
            cursor.copy_expert(copy_sql, buffer)
            conn.commit()
            print("reached after")
            logFile.write(f"Successfully inserted {len(currentDataFrame)} rows from {os.path.basename(csv_filenames[i])}\n")
        except Exception as e:
            logFile.write(f"Insert Error: {e}\n")
            conn.rollback()
            continue
    logFile.write(f" Sector Insertion:\n")
    # End of i loop
    csvSectorFilePath = "../../input/SectorFixedList.csv"
    sector_df = pd.read_csv(csvSectorFilePath)
    sector_df['_source_name'] = 'CSV Import'
    sector_df['_source_filename'] = os.path.basename(csvSectorFilePath)
    row_tuples = [
        (row['symbol'], row['sector'], row['_source_name'], row['_source_filename'])
        for _, row in sector_df.iterrows()
    ]
    try:
        cursor.executemany("""INSERT INTO market.sectors
                                           (symbol, sector, _source_name, _source_filename)
                                       VALUES (%s, %s, %s, %s)""", row_tuples)
        conn.commit()
        logFile.write(f" Successfully inserted Sector Data\n")
    except psycopg2.Error as e:
        logFile.write(f" Insert Error: {e}\n")
        conn.rollback()
    cursor.close()
    conn.close()

#End of Main
if __name__ == "__main__":
    main()