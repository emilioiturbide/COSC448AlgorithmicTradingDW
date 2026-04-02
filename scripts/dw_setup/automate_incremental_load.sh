#!/bin/bash
# ==============================================================================
# Script: automate_incremental_load.sh

# Purpose:
# This script automates the incremental load process for a data pipeline.
# It performs the following steps:
# 1. Loads the .env file to set environment variables.
# 2. Runs the incremental load script to aggregate new data and update the target database.
# 3. Waits for a specified interval before the next incremental load.

# Intended Use:
# This script is designed to be run in a continuous loop, performing an incremental 
#   load of the data warehouse at regular intervals (e.g., every 5 minutes). 
# It is useful for scenarios where you want to keep the data warehouse updated with 
#   the latest data without performing a full refresh, such as for near real-time 
#   data updates or when only a small amount of new data is expected between loads.

# Usage:
# 1. Ensure that the .env file is properly configured with the necessary environment 
#   variables (e.g., database connection details, API keys).
# 2. Make the script executable: chmod +x automate_incremental_load.sh
# 3. Run the script: ./automate_incremental_load.sh
# 4. The script will continue to run indefinitely, performing an incremental load 
#   every specified interval (default is 5 minutes).
# 5. To stop the script, use Ctrl+C in the terminal.

# Output:
# The script will print messages to the console indicating the progress of the 
#   incremental load process, including success or error messages for each step. 
# It will also indicate when it is waiting for the next incremental load.

# Author: Emilio Iturbide Gonzalez
# License: MIT
# ==============================================================================

while true; do

    # load .env file if it exists
    ENV_FILE="../.env"
    if [ -f "$ENV_FILE" ]; then
        . "$ENV_FILE"
    else
        echo "Warning: .env file not found at $ENV_FILE. Make sure to set environment variables manually."
    fi
    echo "Starting incremental load process..."

    module load postgresql/16.0
    # Run the incremental load script
    psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -d $DB_NAME -f ../data_transformation/agg_incremental.sql
    if [ $? -eq 0 ]; then
        echo "Incremental load completed successfully."
    else
        echo "Error occurred during incremental load. Check the logs for details."
    fi

    # Load the aggregated data into the target database
    psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -d $DB_NAME -f ../data_transformation/fill_dw_from_agg.sql
    if [ $? -eq 0 ]; then
        echo "Data loaded into target database successfully."
    else
        echo "Error occurred while loading data into target database. Check the logs for details."
    fi

    # Wait for a specified interval before the next incremental load
    echo "Waiting for the next incremental load..."
    sleep 300 # Wait for 5 minutes
done