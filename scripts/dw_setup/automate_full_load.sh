#!/bin/bash
# ==============================================================================
# Script: automate_full_load.sh

# Copyright (c) 2026 Emilio Iturbide Gonzalez
# This software is licensed under the MIT License, located in the root directory
#   of this project (LICENSE file).
# ==============================================================================

# Use of AI:
# Github Copilot AI was used to help debug the implementation of the script.
# All AI-generated suggestions were reviewed, verified, and modified by the author
#   before inclusion.

# Purpose: 
# This script automates the full load process for a data pipeline.
# It performs the following steps:
# 1. Loads the .env file to set environment variables.
# 2. Runs the full load script to aggregate all data and update the target database.
# 3. Waits for a specified interval before the next full load.

# Intended Use:
# This script is designed to be run in a continuous loop, performing a full load of the 
#   data warehouse at regular intervals (e.g., weekly). 
# It is useful for scenarios where a complete refresh of the data is required periodically, 
#   such as for historical data updates or when significant changes have been made to the data sources.

# Usage:
# 1. Ensure that the .env file is properly configured with the necessary environment 
#       variables (e.g., database connection details, API keys).
# 2. Make the script executable: chmod +x automate_full_load.sh
# 3. Run the script: ./automate_full_load.sh
# 4. The script will continue to run indefinitely, performing a full load every 
#       specified interval (default is 7 days).
# 5. To stop the script, use Ctrl+C in the terminal.

# Output:
# The script will print messages to the console indicating the progress of the 
#   full load process, including success or error messages for each step. 
# It will also indicate when it is waiting for the next full load.

# Author: Emilio Iturbide Gonzalez
# Date Created: 02/05/2026
# Date Last Modified: 04/03/2026
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
    echo "Starting full load process..."
    
    module load postgresql/16.0
    # Run the full load script to aggregate all data and update the target database
    psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -d $DB_NAME -f ../data_transformation/agg_15min.sql
    if [ $? -eq 0 ]; then
        echo "Full load completed successfully."
    else
        echo "Error occurred during full load. Check the logs for details."
    fi

    # Load the aggregated data into the target database
    psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -d $DB_NAME -f ../data_transformation/fill_dw_from_agg.sql
    if [ $? -eq 0 ]; then
        echo "Data loaded into target database successfully."
    else
        echo "Error occurred while loading data into target database. Check the logs for details."
    fi

    # Wait for a specified interval before the next full load
    echo "Waiting for the next full load..."
    sleep 604800 # Wait for 7 days (604800 seconds)
done