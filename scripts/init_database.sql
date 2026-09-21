/*
==========================================================================
Archived - Original Medallion Arch Script
=========================================================================
This script is retained for reference only. It represents the project's original design, which used a medallion (bronze / silver/ gold)

The project was subsequently constrained to an SSIS-based ETL pipeline, and the layering was reworked into three physical databases: an operational data store, a governance registry, and an analytical warehouse. see docs/Design_decision.md for the reasaing and the mapping btw the two.

DO NOT RUN THIS SCRIPT against the current warehouse. It creates a different database and is superseded by scripts/01_create_star_schema.sql.
=================================================================
*/
/*
---
Create Database and Schemas
---
Purpose:
	This script sets up the foundational database structure named 
	'DataWarehouse' for the energy Intelligence Data Warehouse after 
	checking if it already exists.
	It will drop pre-existing database and recreate a new one.
	It also creates the core schemas used in the Medallion Architecture:
	→ bronze: raw ingested data (IEA monthly electricity dataset)
	→ silver: cleaned, standardized and enriched data
	→ gold: dimenional model (STAR schema) for analytics and reporting.

Usage:
	Run this script once at the beginning of the project to initialize the environment.
	It prepares the database for ETL pipelines built in SSIS and supports the Energy Intel 
	analytics layer (SSRS/Tableau).

WARNING:
	Running this script will drop the entire 'DataWarehouse' database if it exists.
	All data in the database will be permanently deleted. Proceed with caution and 
	ensure you have proper backups before running this script
*/

USE master;
GO

-- Drop and recreate the DataWarehouse database
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouse')
BEGIN
	ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE DataWarehouse;
END;
GO

-- Create Database 'DataWarehouse'
CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

-- Create Schemas
CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO
