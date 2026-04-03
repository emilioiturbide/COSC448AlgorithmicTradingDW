# ================================================================================
# Script: insertToDB.py

# Purpose: 
# This script is responsible for inserting raw stock data from CSV files 
#   into the PostgreSQL database. It connects to the database, reads the CSV files, 
#   and uses the COPY command for efficient bulk insertion. 
# It also logs the results of the insertion process, including any errors that occur.

# Intended Use: 
# This script is intended to be run after the database schema and tables have been created. 
# It should be run whenever new raw stock data is available in CSV format that needs to be 
#   ingested into the database.

# Usage: 
# Set the `DATABASE_URL` environment variable if needed and run:
#     python insertToDB.py

# Output: 
# The script will insert data into the appropriate tables in the database and log 
#   the results of the insertion process to a file named `RawInsertLog.txt` in 
#   the `output` directory.

# Author: Justin Drenka
# Original Script Name: DataInsertionFromCSV.py
# Source: https://github.com/youry/AlgorithmicTradingPublic
# License: MIT
# Modified by: Emilio Iturbide - 02/05/2026
# Modifications: Updated connection parameters,
#               removed casting sections to ensure data would land correctly in the DB,
#               added additional audit columns to the staging tables,
#               added logging of insertion results to a file for auditing purposes.

# Note: 
# The script assumes that the CSV files are formatted correctly and that the 
#   database connection parameters are set in the environment variables. 
# It also assumes that the necessary tables have already been created in the 
#   database to receive the data.
# ================================================================================

import psycopg2
import pandas as pd
import os
import glob
from io import StringIO
# ================================================================================
# Modified by Emilio Iturbide - 02/05/2026
# Modifications: Updated connection parameters,
#               Added import of dotenv to load environment variables from .env file 
#               if present, Added error handling for dotenv import to allow script
#               to run even if dotenv is not installed or .env file is missing.
# ================================================================================
try:
    from dotenv import load_dotenv
    load_dotenv(dotenv_path='../.env')
except Exception:
    pass

CONNECTION_PARAMS = {
    'host': os.getenv('DB_HOST'),
    'port': os.getenv('DB_PORT'),
    'database': os.getenv('DB_NAME'),
    'user': os.getenv('DB_USERNAME'),
    'password': os.getenv('DB_PASSWORD')
}
def main():
    # Connect to localhost:15432 (the tunnel endpoint)
    conn = psycopg2.connect(**CONNECTION_PARAMS)
    #Insertion Code
    # ================================================================================
    # Modified by Emilio Iturbide - 02/05/2026
    # Modifications: Updated file paths to match new directory structure,
    # ================================================================================
    # 503 stock CSV files
    #csvStockDirectory = "./input/503_Stocks/"
    # 29 stock CSV files
    csvStockDirectory = "../../input/29_Stocks/"
    csv_files = glob.glob(os.path.join(csvStockDirectory, "*.csv"))
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

            # ================================================================================
            # Modified by Emilio Iturbide - 02/05/2026
            # Modifications: Added _source_name and _source_filename columns to the DataFrame
            #               to track the origin of the data in the database, and filtered the DataFrame
            #               to include only the necessary columns for insertion.
            #               Deleted data casting to avoid casting errors.
            # ================================================================================
            # add _source and _source_filename columns
            currentDataFrame['_source_name'] = 'CSV Import'
            currentDataFrame['_source_filename'] = csv_filenames[i]
            currentDataFrame = currentDataFrame.filter(['date', 'open', 'high', 'low', 'close', 'volume', '_source_name', '_source_filename'])
            # Use COPY for bulk insertion
            buffer = StringIO()
            currentDataFrame.to_csv(buffer, index=False, header=False)
            buffer.seek(0)
            print("reached before")
            # ================================================================================
            # Modified by Emilio Iturbide - 02/05/2026
            # Modifications: Updated COPY command to include new columns and match the 
            #                structure of the staging tables.
            # ================================================================================
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
    # ================================================================================
    # Modified by Emilio Iturbide - 02/05/2026
    # Modifications: Added _source_name and _source_filename columns to the DataFrame
    #               to track the origin of the data in the database, and filtered the DataFrame
    #               to include only the necessary columns for insertion.
    # ================================================================================
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