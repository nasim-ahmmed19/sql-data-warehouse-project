#SQL Data Warehouse Project: Medallion Architecture

This repository contains a modern data warehouse implementation using SQL Server. The project follows the Medallion Architecture to process raw data into actionable insights through structured ETL pipelines.
Architecture Overview

The data flows through three distinct layers:

    Bronze Layer: Stores raw data from various sources (CRM, ERP) in its original format.

    Silver Layer: Cleans, standardizes, and handles data quality issues (e.g., removing duplicates, normalizing gender and marital status).
