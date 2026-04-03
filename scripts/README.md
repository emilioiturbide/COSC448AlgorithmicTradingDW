# Scripts for Data Warehouse Implementation
This directory contains all the scripts necessary for implementing the data warehouse for stock price analysis. The scripts are organized into three main subdirectories:
- `data_collection/`: Contains Python scripts for collecting stock price data from external APIs and inserting it into the PostgreSQL database.
- `data_transformation/`: Contains SQL scripts for transforming raw data into aggregated formats and loading it into the star schema.
- `data_warehouse/`: Contains SQL scripts for creating the star schema for the data warehouse.
## Usage Instructions
1. **Database Setup**: Ensure you have PostgreSQL installed and running. Create a database for this project.
2. **Environment Variables**: Create a `.env` file in the `scripts/` directory with the necessary database connection details and API key (as described in the main README).
3. **Run Data Collection**: Execute the `insertToDB.py` script in the `data_collection/` directory to collect stock price data and insert it into the database.
4. **Run Data Transformation**: Execute the SQL scripts in the `data_transformation/` directory to transform the raw data and load it into the star schema.
5. **Create Star Schema**: Execute the `star_schema.sql` script in the `data_warehouse/` directory to create the star schema in your database.