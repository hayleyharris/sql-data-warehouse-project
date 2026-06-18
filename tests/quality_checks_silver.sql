/*
Quality checks
- null/duplicate PKs
- unwanted spaces in string fields
- data standardization
- invalid date ranges and orders
- data consistency between related fields
*/

-- check for nulls or duplicates in primary key
    SELECT
        cst_id,
        COUNT(*)
    FROM silver.crm_cust_info
    GROUP BY cst_id
    HAVING COUNT(*) > 1 OR cst_id IS NULL

    -- check unwanted spaces
    SELECT cst_lastname
    FROM silver.crm_cust_info
    WHERE cst_lastname != TRIM(cst_lastname)

    -- check for normalization
    SELECT DISTINCT cst_gndr
    FROM silver.crm_cust_info

    SELECT DISTINCT cst_marital_status
    FROM silver.crm_cust_info

    -- check for nulls or duplicates
    SELECT
        prd_id,
        COUNT(*)
    FROM silver.crm_prd_info
    GROUP BY prd_id
    HAVING COUNT(*) > 1 OR prd_id IS NULL

    -- check for unwanted spaces
    SELECT prd_nm
    FROM silver.crm_prd_info
    WHERE prd_nm != TRIM(prd_nm)

    -- check for NULLs or negative numbers
    SELECT prd_cost
    FROM silver.crm_prd_info
    WHERE prd_cost < 0 OR prd_cost IS NULL

    -- check for invalid date orders
    SELECT *
    FROM silver.crm_prd_info
    WHERE prd_end_dt < prd_start_dt

    SELECT
        prd_id,
        prd_key,
        prd_nm,
        prd_start_dt,
        prd_end_dt,
        LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt ASC)-1 as prd_end_dt_test
    FROM silver.crm_prd_info
    WHERE prd_key IN ('AC-HE-HL-U509-R', 'AC-HE-HL-U509')

    SELECT
        NULLIF(sls_ship_dt, 0)
    FROM bronze.crm_sales_details
    WHERE sls_ship_dt <= 0 OR LEN(sls_ship_dt) != 8 OR sls_ship_dt > 20500101 OR sls_ship_dt < 19000101

    SELECT*
    FROM bronze.crm_sales_details
    WHERE sls_ord_dt > sls_ship_dt OR sls_ship_dt > sls_due_dt

    SELECT DISTINCT
        sls_sales as old_sls_sales,
        sls_quantity,
        sls_price as old_sls_price,
        CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
            THEN sls_quantity * ABS(sls_price)
            ELSE sls_sales
        END sls_sales,
        CASE WHEN sls_price IS NULL OR sls_price <= 0
            THEN sls_sales / NULLIF(sls_quantity, 0)
            ELSE sls_price
        END sls_price
    FROM bronze.crm_sales_details
    WHERE sls_sales != sls_quantity * sls_price
    OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
    OR sls_sales <=0 OR sls_quantity <=0 OR sls_price <=0
    ORDER BY sls_sales, sls_quantity, sls_price

    SELECT* FROM [silver].[crm_cust_info];

    SELECT DISTINCT
        bdate
    FROM bronze.erp_cust_az12
    WHERE bdate < '1924-01-10' OR bdate > GETDATE()

    SELECT DISTINCT
        gen
    FROM bronze.erp_cust_az12

    SELECT DISTINCT
        cntry AS old_cntry,
        CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
            WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
            WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
            ELSE TRIM(cntry)
        END as cntry 
    FROM bronze.erp_loc_a101
    ORDER BY cntry
