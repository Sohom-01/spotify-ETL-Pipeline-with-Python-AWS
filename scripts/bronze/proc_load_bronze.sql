/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'bronze' schema from external CSV files.
    It performs the following actions:
    - Truncates the bronze tables before loading data.
    - Uses the `COPY` command to load data from CSV files into bronze tables.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Example:
    CALL bronze.load_bronze();
===============================================================================
*/

CREATE OR REPLACE PROCEDURE bronze.load_bronze()
LANGUAGE plpgsql
AS $$
DECLARE
    start_time       TIMESTAMP;
    end_time         TIMESTAMP;
    batch_start_time TIMESTAMP;
    batch_end_time   TIMESTAMP;
BEGIN
    BEGIN
        batch_start_time := clock_timestamp();

        RAISE NOTICE '======================================';
        RAISE NOTICE 'LOADING BRONZE LAYER';
        RAISE NOTICE '======================================';

        -- ================================
        -- customer_profiles
        -- ================================
        start_time := clock_timestamp();

        RAISE NOTICE '>> TRUNCATING bronze.customer_profiles';
        TRUNCATE TABLE bronze.customer_profiles;

        RAISE NOTICE '>> INSERTING DATA INTO: bronze.customer_profiles';
        COPY bronze.customer_profiles(customer_id, age, gender, location, join_date)
        FROM 'C:\Users\goodb\OneDrive\Desktop\Sohom\Portfolio\Projects\SQL\Coding Ninja\Retail Analytics\Datasets\customer_profiles.csv'
        WITH (FORMAT csv, HEADER true, DELIMITER ',');

        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds', ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::numeric, 2);
        RAISE NOTICE '--------------------------------------';

        -- ================================
        -- product_inventory
        -- ================================
        start_time := clock_timestamp();

        RAISE NOTICE '>> TRUNCATING bronze.product_inventory';
        TRUNCATE TABLE bronze.product_inventory;

        RAISE NOTICE '>> INSERTING DATA INTO: bronze.product_inventory';
        COPY bronze.product_inventory(product_id, product_name, category, stock_level, price)
        FROM 'C:\Users\goodb\OneDrive\Desktop\Sohom\Portfolio\Projects\SQL\Coding Ninja\Retail Analytics\Datasets\product_inventory.csv'
        WITH (FORMAT csv, HEADER true, DELIMITER ',');

        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds', ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::numeric, 2);
        RAISE NOTICE '--------------------------------------';

        -- ================================
        -- sales_transaction
        -- ================================
        start_time := clock_timestamp();

        RAISE NOTICE '>> TRUNCATING bronze.sales_transaction';
        TRUNCATE TABLE bronze.sales_transaction;

        RAISE NOTICE '>> INSERTING DATA INTO: bronze.sales_transaction';
        COPY bronze.sales_transaction(transaction_id, customer_id, product_id, quantity_purchased, transaction_date, price)
        FROM 'C:\Users\goodb\OneDrive\Desktop\Sohom\Portfolio\Projects\SQL\Coding Ninja\Retail Analytics\Datasets\sales_transaction.csv'
        WITH (FORMAT csv, HEADER true, DELIMITER ',');

        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds', ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::numeric, 2);
        RAISE NOTICE '--------------------------------------';

        batch_end_time := clock_timestamp();
        RAISE NOTICE '======================================';
        RAISE NOTICE 'LOADING BRONZE LAYER IS COMPLETED';
        RAISE NOTICE '>> Total Load Duration: % seconds', ROUND(EXTRACT(EPOCH FROM (batch_end_time - batch_start_time))::numeric, 2);
        RAISE NOTICE '======================================';

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '============================================';
            RAISE NOTICE 'ERROR OCCURRED DURING LOADING BRONZE LAYER';
            RAISE NOTICE '============================================';
            RAISE NOTICE 'ERROR MESSAGE: %', SQLERRM;
            RAISE NOTICE 'ERROR STATE (SQLSTATE): %', SQLSTATE;
    END;
END;
$$;
