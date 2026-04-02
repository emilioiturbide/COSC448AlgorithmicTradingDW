#!/bin/bash

while true; do

    # load .env file if it exists
    ENV_FILE="../.env"
    if [ -f "$ENV_FILE" ]; then
        . "$ENV_FILE"
    else
        echo "Warning: .env file not found at $ENV_FILE. Make sure to set environment variables manually."
    fi
    echo "Starting full load process..."
    
    # Run the full load script to aggregate all data and update the target database
    psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -d $DB_NAME -f ../data_transformation/agg_full.sql
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