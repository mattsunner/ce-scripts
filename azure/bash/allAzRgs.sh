#!/bin/bash

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "Azure CLI is not installed. Please install it first."
    exit 1
fi

# Authenticate with Azure CLI
echo "Ensuring you are logged in to Azure..."
az account show &> /dev/null
if [ $? -ne 0 ]; then
    echo "You are not logged in to Azure. Please log in."
    az login
fi

# Define the KQL query
KQL_QUERY="Resources | project resourceGroup, location, tags, subscriptionId, sku=properties.sku.tier"

# Execute the query using Azure CLI and output results
echo "Running the query..."
az graph query -q "$KQL_QUERY" --output table

# Optional: Save output to a file
# Uncomment the next line if you'd like to save the results to a CSV file
# az graph query -q "$KQL_QUERY" --output tsv > resources.csv

echo "Query execution completed."

