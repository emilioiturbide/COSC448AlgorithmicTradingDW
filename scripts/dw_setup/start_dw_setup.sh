#!/bin/bash
# ==============================================================================
# Script: start_dw_setup.sh

# Purpose:
# This script initializes the data warehouse setup process by performing the following steps:
# 1. Loads the .env file to set environment variables.
# 2. Runs the star schema creation script to set up the data warehouse schema and tables.
# 3. Creates the aggregation tables needed for data transformation.
# 4. Loads the initial data into the data warehouse from the aggregation tables.

# Intended Use:
# This script is designed to be run once to set up the data warehouse environment. 
# It is useful for scenarios where you are setting up the data warehouse for the first 
#   time or when you need to reset the data warehouse to a clean state.

# Usage:
# 1. Ensure that the .env file is properly configured with the necessary 
#    environment variables (e.g., database connection details, API keys).
# 2. Make the script executable: chmod +x start_dw_setup.sh
# 3. Run the script: ./start_dw_setup.sh
# 4. The script will print messages to the console indicating the progress of the 
#       setup process, including success or error messages for each step.

# Output:
# The script will print messages to the console indicating the progress of the 
#       data warehouse setup process, including success or error messages for each step.

# Author: Emilio Iturbide Gonzalez
# License: MIT
# ==============================================================================


ENV_FILE="../.env"
if [ -f "$ENV_FILE" ]; then
    . "$ENV_FILE"
else
    echo "Warning: .env file not found at $ENV_FILE. Make sure to set environment variables manually."
fi
echo "Starting data warehouse setup process..."
module load postgresql/16.0
# Run the setup script to create the data warehouse schema and tables
psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -d $DB_NAME -f ../data_warehouse/star_schema.sql
if [ $? -eq 0 ]; then
    echo "Star schema tables created successfully."
else
    echo "Error occurred during star schema creation."
fi

echo "Creating aggregation tables..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -d $DB_NAME -f ../data_transformation/agg_15min.sql
if [ $? -eq 0 ]; then
    echo "Aggregation tables created successfully."
else
    echo "Error occurred during aggregation table creation."
fi

echo "Loading initial data into the data warehouse..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -d $DB_NAME -f ../data_transformation/fill_dw_from_agg.sql
if [ $? -eq 0 ]; then
    echo "Initial data loaded into data warehouse successfully."
else
    echo "Error occurred while loading initial data into data warehouse."
fi
