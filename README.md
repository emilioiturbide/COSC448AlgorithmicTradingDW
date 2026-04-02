# Data Warehouse for Stock Price Analysis
This project implements a data warehouse for stock price analysis using PostgreSQL. It includes scripts for data collection, transformation, and loading (ETL) from raw stock price data to a star schema optimized for analytical queries.
## Project Structure
- `scripts/`: Contains all the SQL and Python scripts for data collection, transformation, and loading.
  - `data_collection/`: Python scripts to collect stock price data and insert it into the database.
  - `data_transformation/`: SQL scripts to transform raw data into aggregated formats and load it into the star schema.
  - `data_warehouse/`: SQL script to create the star schema for the data warehouse.
## Setup Instructions
1. **Database Setup**: Ensure you have PostgreSQL installed and running. Create a database for this project.
2. **Environment Variables**: Create a `.env` file in the `scripts/` directory with the following content, replacing the placeholders with your actual database connection details and API key:
   ```
   DB_HOST=your_db_host
   DB_PORT=your_db_port
   DB_USERNAME=your_db_username
   DB_PASSWORD=your_db_password
   DB_NAME=your_db_name
   FMP_API_KEY=your_fmp_api_key
   ```
3. **Run Data Collection**: Execute the `insertToDB.py` script to collect stock price data and insert it into the database.
4. **Run Data Transformation**: Execute the SQL scripts in the `data_transformation/` directory to transform the raw data and load it into the star schema.
5. **Create Star Schema**: Execute the `star_schema.sql` script in the `data_warehouse/` directory to create the star schema in your database.
## Author
Emilio Iturbide Gonzalez
## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.