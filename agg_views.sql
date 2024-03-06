-- Create agg views
-- Combine all the data together
CREATE OR REPLACE VIEW agg_full_dataset AS
	SELECT ord.der_order_id,
		   ord.order_id,
		   ord.customer_id,
		   ord.order_date,
		   ord.priority,
		   ord.city,
		   ord.state,
		   ord.country,
		   ord.region,
		   ordprd.quantity,
		   ordprd.sale_amt,
		   ordprd.discount,
		   ordprd.profit,
		   ordprd.ship_date,
		   ordprd.ship_mode,
		   ordprd.ship_cost,
		   prd.der_product_id,
		   prd.product_id,
		   prd.product_name,
		   prd.category,
		   prd.subcategory,
		   cust.customer_name,
		   cust.segment,
		   cust.market
	FROM public.orders ord
	JOIN public.orders_products ordprd
	ON ord.der_order_id = ordprd.der_order_id
	JOIN public.products prd
	ON ordprd.der_product_id = prd.der_product_id
	JOIN public.customers cust
	ON ord.customer_id = cust.customer_id;
	
SELECT *
FROM public.agg_full_dataset
WHERE der_product_id = 55
LIMIT 20;

SELECT MIN(discount), MAX(discount)
FROM public.agg_full_dataset;
-- 0
-- 0.85

SELECT der_product_id, COUNT(distinct discount)
FROM public.agg_full_dataset
GROUP BY der_product_id
HAVING COUNT(distinct discount) > 1;



-- agg_market_sales
CREATE OR REPLACE VIEW agg_market_sales AS
	SELECT 
		market,
		region,
		country,
		DATE_PART('year', order_date) AS order_year, 
		DATE_PART('month', order_date) AS order_month, 
		count(DISTINCT der_order_id) AS total_orders,
		sum(sale_amt) AS total_sales,
		avg(sale_amt) AS average_sale,
		count(DISTINCT customer_id) AS total_customers
	FROM public.agg_full_dataset
	GROUP BY market, region, country, order_year, order_month
	ORDER BY market, region, country, order_year, order_month;

-- agg_customers
CREATE OR REPLACE VIEW agg_customers AS
	SELECT 
		customer_id,
		customer_name,
		market,
		country,
		DATE_PART('year', order_date) AS order_year, 
		DATE_PART('month', order_date) AS order_month,
		sum(sale_amt) AS total_sales
	FROM public.agg_full_dataset
	GROUP BY customer_id, customer_name, market, country, order_year, order_month
	ORDER BY customer_id, customer_name, market, country, order_year, order_month;
	
-- agg_products
-- choose a product_name to go with each distinct product_id
-- will choose the last one (arbitrary decision)
SELECT product_id,
	   product_name
INTO public.TEMP_product_lu
FROM
(SELECT product_id,
	   product_name,
	   ROW_NUMBER() OVER(PARTITION BY product_id
						 ORDER BY der_product_id DESC) as "row_num"
FROM public.agg_full_dataset) DEDUPE
WHERE row_num = 1;

CREATE OR REPLACE VIEW agg_products AS
	SELECT 
		full_ds.product_id,
		prod_lu.product_name,
		category,
		subcategory,
		DATE_PART('year', order_date) AS order_year, 
		DATE_PART('month', order_date) AS order_month,
		AVG(discount) AS avg_discount,
		SUM(profit) AS total_profit,
		SUM(quantity) AS total_quantity,
		SUM(sale_amt) AS total_sales
	FROM public.agg_full_dataset full_ds
	JOIN public.TEMP_product_lu prod_lu
	ON full_ds.product_id = prod_lu.product_id
	GROUP BY full_ds.product_id, prod_lu.product_name, category, 
			 subcategory, order_year, order_month
	ORDER BY full_ds.product_id, prod_lu.product_name, category, 
			 subcategory, order_year, order_month;