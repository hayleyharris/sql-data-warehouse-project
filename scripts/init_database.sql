/*
=========================================
Create DB and Schemas
=========================================
Script purpose:
- create new DB names 'DataWarehouse' after checking if it already exits
- if exists, drop and recreated
- sets up 3 schemas, 'bronze', 'silver' and 'gold'

Warning:
- this script will drop the 'DataWarehouse' DB if it already exists, so make sure to backup any important data before running it.
*/


-- create database 'DataWarehouse'
USE master;
GO

-- drop and recreate the 'DataWarehouse' DB
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouse')
BEGIN
    ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouse;
END;
GO

-- create 'Datawarehouse' DB
CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
GO
