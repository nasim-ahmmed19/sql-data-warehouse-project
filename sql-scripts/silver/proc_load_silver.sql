/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'bronze' schema from external CSV files. 
    It performs the following actions:
    - Truncates the bronze tables before loading data.
    - Uses the `BULK INSERT` command to load data from csv Files to bronze tables.

Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC bronze.load_bronze;
===============================================================================
*/﻿

create or ALTER     procedure silver.load_silver as 
begin
	set nocount on;
	declare @row int,@start_time datetime,@end_time datetime,@batch_start_time datetime,@batch_end_time datetime;
	begin try
		print'________________________________________________________________________________________';
		print '       *****  Cleaning All Raw data and Insert clean data in silver layer  *****       ';
		print'________________________________________________________________________________________';
		print''
	
			--------------- 1. crm customer data cleaing --------------------------------------
			--------------------------------------------------------------------------------
			set @batch_start_time =GETDATE();
			print'--------------**** Cleaing CRM Table Raw data and insert ****--------------';
			print''
			print'-----*** Cleaning CRM_CUSTOMER_INFO Table and Insert Clean data ***-----';
			print'Truncate silver.crm_cust_info ....';
			set @start_time=GETDATE();
			--truncate silver table
			truncate table silver.crm_cust_info;

			print'cleaning & inserting data into silver.crm_cust_info ....';
			-- insert all clean data in silver.crm_customer table
			insert into silver.crm_cust_info (cst_id,cst_key,cst_fullname,cst_marital_status,cst_gndr,cst_create_date)
	
			---cleaing all crm_customer table
			select 
				cst_id,
				cst_key,
				concat(coalesce(trim(cst_firstname),''),' ',coalesce(trim(cst_lastname),'')) as cst_fullname,
				case
					when upper(trim(cst_marital_status)) ='S' then 'Single'
					when upper(trim(cst_marital_status))='M' then 'Married'
					else 'n/a'
				end as cst_marital_status,
				case
					when upper(trim(cst_gndr))='M' then 'Male'
					when upper(trim(cst_gndr))='F' then 'Female'
					else 'n/a'
				end as cst_gndr,
				cst_create_date
			from
				(select 
					*,
					ROW_NUMBER() over(partition by cst_id order by cst_create_date desc) 
					as flag_last 
				from bronze.crm_cust_info where cst_id is not null)t where flag_last=1;
			set @row=@@ROWCOUNT;
			set @end_time=GETDATE();
			

			print 'crm_cust_info: '+cast(@row as nvarchar)+' rows clean and load in: '+cast(datediff(millisecond,@start_time,@end_time) as nvarchar)+' millisecond';
			print('------------------------********------------------------');
			---------------------------------------------------------------------------


			-----------------2. crm product data cleaing -------------------------
			-------------------------------------------------------------------
			set @start_time=GETDATE();
			print''
			print'-----*** Cleaning CRM_PRODUCT_INFO Table and Insert Clean data ***-----';
			print'Truncate silver.crm_product_info ....';
			--truncate silver.crm_prd_info table if the table is not empty
			truncate table silver.crm_prd_info;

			print'cleaning & inserting data into silver.crm_product_info ....'
			--insert all clean data in silver.crm_prd_info table
			insert into silver.crm_prd_info(prd_id,cat_id,prd_key,prd_nm,prd_cost,prd_line,prd_start_dt,prd_end_dt)

			--cleaing crm product table
			(select 
				prd_id,
				replace(LEFT(prd_key,5),'-','_') as cat_id,
				SUBSTRING(prd_key,7,len(prd_key)) as prd_key,
				prd_nm,
				isnull(prd_cost,0) as prd_cost,
				case
					when upper(trim(prd_line))='R' then 'Road'
					when upper(trim(prd_line))='M' then 'Mountain'
					when upper(trim(prd_line))='S' then 'Other Sales'
					when upper(trim(prd_line))='T' then 'Touring'
					else 'n/a'
				end as prd_line,
				prd_start_dt,
				lead(prd_start_dt) over(partition by prd_key order by prd_start_dt)-1 
				as prd_end_dt
			from bronze.crm_prd_info);
			set @row=@@ROWCOUNT
			set @end_time=GETDATE();
			print 'crm_prd_info: '+cast(@row as nvarchar)+' rows clean and load in: '+cast(datediff(millisecond,@start_time,@end_time) as nvarchar)+' millisecond';
			print('------------------------********------------------------');

			---------------------------------------------------------------



			-----------------3. crm slaes data cleaing -----------------------
			---------------------------------------------------------------
			set @start_time=GETDATE();
			print''
			print'-----*** Cleaning crm_sales_details Table and Insert Clean data ***-----';
			print'Truncate silver.crm_sales_details ....';
			--truncate crm_sales_details table
			truncate table silver.crm_sales_details;

			print'cleaning & inserting data into silver.crm_sales_details ....';

			with cleanSales as (
			select 
				sls_ord_number,sls_prd_key,sls_cust_id,sls_order_dt,sls_ship_dt,sls_due_dt,
				--sales column validation
				case
					when sls_sales is null or sls_sales<=0 or sls_sales !=sls_quantity * sls_price then abs(sls_price) * sls_quantity
					else sls_sales
				end as sls_sales,
				sls_quantity,
				sls_price
			from bronze.crm_sales_details ) 

			--insert all clean data in crm_sales_details
			insert into silver.crm_sales_details (sls_ord_number,sls_prd_key,sls_cust_id,sls_order_dt,sls_ship_dt,sls_due_dt,sls_sales,sls_quantity,
				sls_price)

			--all data cleaning . date ,price validation
			select 
				sls_ord_number,sls_prd_key,sls_cust_id,
				case
					when sls_order_dt =0 or len(sls_order_dt)!=8 then null
					else cast(cast(sls_order_dt as varchar) as date)
				end as sls_order_dt,
				case 
					when sls_ship_dt =0 or len(sls_ship_dt) !=8 then null
					else cast(cast(sls_ship_dt as varchar) as date)
				end as sls_ship_dt,
				case
					when sls_due_dt =0 or len(sls_due_dt) !=8 then null
					else cast(cast(sls_due_dt as varchar) as date)
				end as sls_due_dt,
				sls_sales,
				sls_quantity,
				case 
					when sls_price is null or sls_price <=0 or sls_price !=sls_sales/sls_quantity then sls_sales/nullif(sls_quantity,0) 
					else sls_price 
				end as sls_price
			from cleanSales ;
			set @row=@@ROWCOUNT;
			set @end_time=GETDATE();
			print 'crm_sales_details: '+cast(@row as nvarchar)+' rows clean and load in: '+cast(datediff(millisecond,@start_time,@end_time) as nvarchar)+' millisecond';
			print('------------------------********------------------------');
			----------------------------------------------------------------


			---------------4. erp customer table-------------------------------
			----------------------------------------------------------------
			set @start_time=GETDATE();
			print''
			print'-----*** Cleaning erp_cust_az12 Table and Insert Clean data ***-----';
			print'Truncate silver.erp_cust_az12 ....';
			--Truncate table
			truncate table silver.erp_cust_az12;

			
			print'cleaning & inserting data into silver.erp_cust_az12 ....';
			--insert into all clean data in silver.erp_cust_az12
			insert into silver.erp_cust_az12 (cid,bdate,gen)

			---cleaning customer table
			select 
				case 
					when cid like 'NAS%' then SUBSTRING(cid,4,len(cid))--remove NAS
					else cid
				end as cid,
				case
					when bdate >GETDATE() then null 
					else bdate
				end as bdate, --correct wrong date
				case 
					when upper(trim(gen)) in ('F','FEMALE') then 'Female'
					when upper(trim(gen)) in ('M','MALE') then 'Male'
					else 'n/a'
				end as gen  --Normalize gender values and handle unknown case
			from bronze.erp_cust_az12;
			set @row=@@ROWCOUNT;
			set @end_time=GETDATE();
			print 'erp_cust_az12: '+cast(@row as nvarchar)+' rows clean and load in: '+cast(datediff(millisecond,@start_time,@end_time) as nvarchar)+' millisecond';
			print('------------------------********------------------------');
			---------------------------------------------------------------------

			-------------------------5. erp location table cleaning--------------------------
			------------------------------------------------------------------------
			set @start_time=GETDATE();
			print''
			print'-----*** Cleaning erp_loc_a101 Table and Insert Clean data ***-----';
			print'Truncate silver.erp_loc_a101 ....';
			--truncate table
			truncate table silver.erp_loc_a101;

			print'cleaning & inserting data into silver.erp_loc_a101 ....';
			--insert all clean data in silver.erp_loc_a101
			insert into silver.erp_loc_a101 (cid,cntry)

			select 
				REPLACE(cid,'-','') as cid,
				case
					when trim(cntry)='DE' then 'Germany'
					when trim(cntry) in ('US','USA') THEN 'United States'
					when trim(cntry)='' or trim(cntry) is NULL then 'n/a'
					else trim(cntry)
				end as cntry  --Normalize and Handle missing or blank country codes
			from bronze.erp_loc_a101 ;
			set @row=@@ROWCOUNT;
			set @end_time=GETDATE();
			print 'erp_loc_a101: '+cast(@row as nvarchar)+' rows clean and load in: '+cast(datediff(millisecond,@start_time,@end_time) as nvarchar)+' millisecond';
			print('------------------------********------------------------');
			----------------------------------------------------------------------------

			------------------------6. product category table cleaning--------------------
			------------------------------------------------------------------------------
			set @start_time=GETDATE();
			print''
			print'-----*** Cleaning .erp_px_cat_g1v2 Table and Insert Clean data ***-----';
			print'Truncate silver..erp_px_cat_g1v2 ....';
			--truncate table
			truncate table silver.erp_px_cat_g1v2;

			print'cleaning & inserting data into silver.erp_px_cat_g1v2 ....';
			--insert all clan data in silver.erp_px_ca_g1v2
			insert into silver.erp_px_cat_g1v2 (id,cat,subcat,maintenance)

			--cleaning data
			select 
				id,
				cat,
				subcat,
				maintenance
			from bronze.erp_px_cat_g1v2
			set @row=@@ROWCOUNT;
			set @end_time=GETDATE();
			print 'erp_px_cat_g1v2: '+cast(@row as nvarchar)+' rows clean and load in: '+cast(datediff(millisecond,@start_time,@end_time) as nvarchar)+' millisecond';
			set @batch_end_time=GETDATE();
			print('------------------------********------------------------');
			print''
			print'All data claning and loading time in: '+cast(datediff(millisecond,@batch_start_time,@batch_end_time) as nvarchar)+' millisecond';
			print'______________________________________ ***** ______________________________________'

	end try
	begin catch
		print'______________________________________ ***** ______________________________________'
		PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER'
		print'Error Message: '+error_message();
		print 'Error Number: '+CAST(Error_number() as nvarchar);
		print 'Error State: '+cast(error_state() as nvarchar);
		print'______________________________________ ***** ______________________________________'
	end catch
end;

