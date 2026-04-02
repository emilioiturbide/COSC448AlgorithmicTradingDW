#!/bin/bash

# This script automates the incremental load process for a data pipeline.
# It performs the following steps:
# Runs the incremental load script to aggregate new data and update the target database.

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
    sleep 30 # Wait for 30 seconds
done