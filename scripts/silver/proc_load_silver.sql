/*
Stored Procedure: Load Silver (Bronze -> Silver)
- truncates silver tables
- inserts transformed and cleaned from Bronze to Silver

use:
EXEC silver.load_silver

*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN

    -- data transformation and data cleaning
    INSERT INTO silver.crm_cust_info (
        cst_id,
        cst_key,
        cst_firstname,
        cst_lastname,
        cst_marital_status,
        cst_gndr,
        cst_create_date
    )
    SELECT 
        cst_id,
        cst_key,
        TRIM(cst_firstname),
        TRIM(cst_lastname),
        CASE WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
            WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
            ELSE 'n/a'
        END cst_marital_status,
            CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
            WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
        ELSE 'n/a'
        END cst_gndr,
        cst_create_date
    FROM (
    SELECT*,
        ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) as flag_last
    FROM bronze.crm_cust_info
    )t WHERE flag_last = 1

    -- -- check for nulls or duplicates in primary key
    -- SELECT
    --     cst_id,
    --     COUNT(*)
    -- FROM silver.crm_cust_info
    -- GROUP BY cst_id
    -- HAVING COUNT(*) > 1 OR cst_id IS NULL

    -- -- check unwanted spaces
    -- SELECT cst_lastname
    -- FROM silver.crm_cust_info
    -- WHERE cst_lastname != TRIM(cst_lastname)

    -- -- check for normalization
    -- SELECT DISTINCT cst_gndr
    -- FROM silver.crm_cust_info

    -- SELECT DISTINCT cst_marital_status
    -- FROM silver.crm_cust_info

    -- second table
    INSERT INTO silver.crm_prd_info (    
        prd_id,
        cat_id,
        prd_key,
        prd_nm,
        prd_cost,
        prd_line,
        prd_start_dt,
        prd_end_dt
    )
    SELECT 
        prd_id,
        REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
        SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,
        prd_nm,
        ISNULL(prd_cost, 0) AS prd_cost,
        CASE UPPER(TRIM(prd_line))
            WHEN 'M' THEN 'Mountain'
            WHEN 'R' THEN 'Road'
            WHEN 'S' THEN 'other Sales'
            WHEN 'T' THEN 'Touring'
            ELSE 'n/a'
        END AS prd_line,
        CAST(prd_start_dt AS DATE) AS prd_start_dt,
        CAST(LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt ASC)-1 AS DATE) as prd_end_dt
    FROM bronze.crm_prd_info

    -- -- check for nulls or duplicates
    -- SELECT
    --     prd_id,
    --     COUNT(*)
    -- FROM silver.crm_prd_info
    -- GROUP BY prd_id
    -- HAVING COUNT(*) > 1 OR prd_id IS NULL

    -- -- check for unwanted spaces
    -- SELECT prd_nm
    -- FROM silver.crm_prd_info
    -- WHERE prd_nm != TRIM(prd_nm)

    -- -- check for NULLs or negative numbers
    -- SELECT prd_cost
    -- FROM silver.crm_prd_info
    -- WHERE prd_cost < 0 OR prd_cost IS NULL

    -- -- check for invalid date orders
    -- SELECT *
    -- FROM silver.crm_prd_info
    -- WHERE prd_end_dt < prd_start_dt

    -- SELECT
    --     prd_id,
    --     prd_key,
    --     prd_nm,
    --     prd_start_dt,
    --     prd_end_dt,
    --     LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt ASC)-1 as prd_end_dt_test
    -- FROM silver.crm_prd_info
    -- WHERE prd_key IN ('AC-HE-HL-U509-R', 'AC-HE-HL-U509')

    -- third table
    INSERT INTO silver.crm_sales_details (
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        sls_order_dt,
        sls_ship_dt,
        sls_due_dt,
        sls_sales,
        sls_quantity,
        sls_price
    )
    SELECT
        sls_ord_num,
        sls_prod_key,
        sls_cust_id ,
        CASE WHEN sls_ord_dt = 0 OR LEN(sls_ord_dt) != 8 THEN NULL
            ELSE CAST(CAST(sls_ord_dt AS VARCHAR) AS DATE)
        END AS sls_order_dt,
        CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
            ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
        END AS sls_ship_dt,
        CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
            ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
        END AS sls_due_dt,
        CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
            THEN sls_quantity * ABS(sls_price)
            ELSE sls_sales
        END sls_sales,
        sls_quantity,
        CASE WHEN sls_price IS NULL OR sls_price <= 0
            THEN sls_sales / NULLIF(sls_quantity, 0)
            ELSE sls_price
        END sls_price
    FROM bronze.crm_sales_details

    -- SELECT
    --     NULLIF(sls_ship_dt, 0)
    -- FROM bronze.crm_sales_details
    -- WHERE sls_ship_dt <= 0 OR LEN(sls_ship_dt) != 8 OR sls_ship_dt > 20500101 OR sls_ship_dt < 19000101

    -- SELECT*
    -- FROM bronze.crm_sales_details
    -- WHERE sls_ord_dt > sls_ship_dt OR sls_ship_dt > sls_due_dt

    -- SELECT DISTINCT
    --     sls_sales as old_sls_sales,
    --     sls_quantity,
    --     sls_price as old_sls_price,
    --     CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
    --         THEN sls_quantity * ABS(sls_price)
    --         ELSE sls_sales
    --     END sls_sales,
    --     CASE WHEN sls_price IS NULL OR sls_price <= 0
    --         THEN sls_sales / NULLIF(sls_quantity, 0)
    --         ELSE sls_price
    --     END sls_price
    -- FROM bronze.crm_sales_details
    -- WHERE sls_sales != sls_quantity * sls_price
    -- OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
    -- OR sls_sales <=0 OR sls_quantity <=0 OR sls_price <=0
    -- ORDER BY sls_sales, sls_quantity, sls_price

    -- fourth table
    INSERT INTO silver.erp_cust_az12 (
        cid,
        bdate,
        gen
    )
    SELECT
        CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
            ELSE cid
        END as cid,
        CASE WHEN bdate > GETDATE() THEN NULL
            ELSE bdate
        END as bdate,
        CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
            WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
            ELSE 'n/a'
        END as gen
    FROM bronze.erp_cust_az12

    -- SELECT* FROM [silver].[crm_cust_info];

    -- SELECT DISTINCT
    --     bdate
    -- FROM bronze.erp_cust_az12
    -- WHERE bdate < '1924-01-10' OR bdate > GETDATE()

    -- SELECT DISTINCT
    --     gen
    -- FROM bronze.erp_cust_az12

    -- fifth table
    INSERT INTO silver.erp_loc_a101(cid, cntry)
    SELECT 
        REPLACE(cid, '-', '') cid,
        CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
            WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
            WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
            ELSE TRIM(cntry)
        END as cntry 
    FROM bronze.erp_loc_a101

    -- SELECT DISTINCT
    --     cntry AS old_cntry,
    --     CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
    --         WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
    --         WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
    --         ELSE TRIM(cntry)
    --     END as cntry 
    -- FROM bronze.erp_loc_a101
    -- ORDER BY cntry

    -- sixth table
    INSERT INTO silver.erp_px_cat_g1v2 (id, cat, subcat, maintenance)
    SELECT
        id, 
        cat,
        subcat,
        maintenance
    FROM bronze.erp_px_cat_g1v2
END;
