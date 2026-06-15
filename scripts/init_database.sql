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
