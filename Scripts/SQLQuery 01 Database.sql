USE master;
GO

-- Drop and recreate the 'DataWarehouseAnalytics' database

IF EXISTS (SELECT 1 FROM sys.databases WHERE NAME = 'DataWarehouseAnalytics')
BEGIN
    ALTER DATABASE DataWarehouseAnalytics SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouseAnlaytics;
END; 
GO

-- Create the 'DataWarehouseAnalytics' Database

CREATE DATABASE DataWarehouseAnalytics;
GO

USE DataWarehouseAnalytics;
GO

-- Create Schemas

CREATE SCHEMA Gold;
GO

CREATE TABLE Gold.dim_customers (
    Customer_Key INT,
    Customer_ID INT,
    Customer_Number NVARCHAR(50),
    First_Name NVARCHAR(50),
    Last_Name NVARCHAR(50),
    Country NVARCHAR(50),
    Maritsl_Status NVARCHAR(50),
    Gender NVARCHAR(50),
    Birth_Date DATE,
    Create_Date DATE
);
GO

CREATE TABLE Gold.dim_products (
    Product_Key INT,
    Product_ID INT,
    Product_Number NVARCHAR(50),
    Product_Name NVARCHAR(50),
    Category_ID NVARCHAR(50),
    Category NVARCHAR(50),
    Sub_Category NVARCHAR(50),
    Maintenance NVARCHAR(50),
    Product_Cost INT,
    Product_Line NVARCHAR(50),
    Product_Start_Date DATE
);
GO

CREATE TABLE Gold.fact_sales (
    Order_Number NVARCHAR(50),
    Product_Key INT,
    Customer_Key INT,
    Order_Date DATE,
    Ship_Date DATE,
    Due_Date DATE,
    Sales_Amount INT,
    Sales_Quantity TINYINT,
    Sales_Price INT
);
GO

TRUNCATE TABLE Gold.dim_customers;
GO

BULK INSERT Gold.dim_customers
FROM 'C:\Users\PC\OneDrive\Desktop\SQL\GOLD LAYER TABLES\Gold.dim_customers.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	TABLOCK
);
GO


TRUNCATE TABLE Gold.dim_products;
GO

BULK INSERT Gold.dim_products
FROM 'C:\Users\PC\OneDrive\Desktop\SQL\GOLD LAYER TABLES\Gold.dim_products.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	TABLOCK
);
GO


TRUNCATE TABLE Gold.fact_sales;
GO

BULK INSERT Gold.fact_sales
FROM 'C:\Users\PC\OneDrive\Desktop\SQL\GOLD LAYER TABLES\Gold.fact_sales.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	TABLOCK
);
GO