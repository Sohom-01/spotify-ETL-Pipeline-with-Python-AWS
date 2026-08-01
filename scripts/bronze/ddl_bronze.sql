/*
===============================================================================
DDL Script: Create Bronze Tables
===============================================================================
Script Purpose:
    This script creates tables in the 'bronze' schema, dropping existing tables 
    if they already exist.
	 Run this script to re-define the DDL structure of 'bronze' Tables
===============================================================================
*/

CREATE SCHEMA IF NOT EXISTS bronze;

DO $$
BEGIN
	RAISE NOTICE 'DDL_BRONZE';
	RAISE NOTICE '======================================================';

	RAISE NOTICE 'CREATING TABLES:';
	RAISE NOTICE '---------------------';

	-- Customer Profile
	RAISE NOTICE 'CREATING TABLE bronze.customer_profiles';
	DROP TABLE IF EXISTS bronze.customer_profiles;
	CREATE TABLE bronze.customer_profiles
	(
		customer_id			  INTEGER PRIMARY KEY,
		age					  SMALLINT,
		gender				  VARCHAR(20),
		location			  VARCHAR(50),
		join_date			  DATE
	);
	RAISE NOTICE '>> CREATED TABLE bronze.customer_profiles';

	-- Product Inventory
	RAISE NOTICE 'CREATING TABLE bronze.product_inventory';
	DROP TABLE IF EXISTS bronze.product_inventory;
	CREATE TABLE bronze.product_inventory
	(
		product_id 			INTEGER PRIMARY KEY,
		product_name		VARCHAR(100),
		category			VARCHAR(50),
		stock_level			INTEGER,
		price				NUMERIC(10,2)
	);
	RAISE NOTICE '>> CREATED TABLE bronze.product_inventory';

	-- Sales Transaction
	RAISE NOTICE 'CREATING TABLE bronze.sales_transaction';
	DROP TABLE IF EXISTS bronze.sales_transaction;
	CREATE TABLE bronze.sales_transaction 
	(
	    transaction_id      INTEGER,
	    customer_id         INTEGER,
	    product_id          INTEGER,
	    quantity_purchased  INTEGER,
	    transaction_date    DATE,
	    price               NUMERIC(10, 2)
	);
	RAISE NOTICE '>> CREATED TABLE bronze.sales_transaction';

	RAISE NOTICE '======================================================';
	RAISE NOTICE 'TABLES CREATED';
	
END $$
