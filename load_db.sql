-- walmart database
-- load the target tables

-- DROP TABLE customers;
CREATE TABLE IF NOT EXISTS customers (
	customer_id varchar(50) PRIMARY KEY,
	customer_name varchar(75),
	segment varchar(50),
	market varchar(50),
	file_id int,
	record_id int,
	insert_date timestamp
);

-- DROP TABLE orders;
CREATE TABLE IF NOT EXISTS orders (
    der_order_id serial PRIMARY KEY,
	order_id varchar(50) NOT NULL,
	customer_id varchar(50) NOT NULL REFERENCES customers (customer_id) ON DELETE CASCADE,
	order_date timestamp NOT NULL,
	priority varchar(50),
	city varchar(75),
	state varchar(100),
	country varchar(100),
	region varchar(50),
	file_id int,
	record_id int,
	insert_date timestamp,
	UNIQUE(order_id, customer_id, order_date)
);

-- DROP TABLE products;
CREATE TABLE IF NOT EXISTS products (
	der_product_id serial PRIMARY KEY,
	product_id varchar(50) NOT NULL,
	product_name varchar(200) NOT NULL,
	category varchar(50),
	subcategory varchar(50),
	file_id int,
	record_id int,
	insert_date timestamp,
	UNIQUE(product_id, product_name)
);

-- DROP TABLE orders_products;
CREATE TABLE IF NOT EXISTS orders_products (
    id serial PRIMARY KEY,
	der_order_id int REFERENCES orders (der_order_id) ON DELETE CASCADE,
	der_product_id int REFERENCES products (der_product_id) ON DELETE CASCADE,
	quantity int,
	sale_amt float,
	discount float,
	profit float,
	ship_date timestamp,
	ship_mode varchar(50),
	ship_cost float,
	file_id int,
	record_id int,
	insert_date timestamp,
	UNIQUE(der_order_id, der_product_id)
);

-- Load the customers table
-- Find all the unique customers
-- For dupes of customer_id, take the record that appears latest in the file
-- If we were loading multiple files we would want to only insert customers
-- with customer_id values that didn't already appear in the customers table
-- and update records for customers who already appeared in the table
-- we would also want to add audit fields with the insert and update dates
-- as well as insert and update user IDs or job IDs
INSERT INTO public.customers
SELECT dedupe.customer_id,
	   dedupe.customer_name,
	   dedupe.segment,
	   dedupe.market,
	   dedupe.file_id,
	   dedupe.record_id,
	   now() AS insert_date
FROM (SELECT customer_id,
	   customer_name,
	   segment,
	   market,
	   file_id,
	   id AS record_id,
	   ROW_NUMBER() OVER(PARTITION BY customer_id
						 ORDER BY id DESC) as "row_num"
FROM public.stg_orders) dedupe
WHERE row_num = 1;

-- verifying the number of rows inserted
SELECT COUNT(*)
FROM public.customers;
-- 4873

SELECT COUNT(DISTINCT customer_id)
FROM public.stg_orders;
-- 4873

-- Load the orders table
-- Find all the unique orders (order_id/customer_id/order_date)
-- For dupe orders, take the record with the largest row_id
-- DROP TABLE TEMP_deduped_orders
SELECT order_id,
	   customer_id,
	   product_id,
	   order_date,
	   priority,
	   city,
	   state,
	   country,
	   region,
	   file_id,
	   id AS record_id,
	   ROW_NUMBER() OVER(PARTITION BY order_id, customer_id, order_date
						 ORDER BY row_id DESC) as "row_num"
INTO public.TEMP_deduped_orders
FROM public.stg_orders;

INSERT INTO public.orders (
	order_id,
    customer_id,
    order_date,
    priority,
    city,
    state,
    country,
    region,
    file_id,
    record_id,
    insert_date)
SELECT order_id,
	   customer_id,
	   order_date,
	   priority,
	   city,
	   state,
	   country,
	   region,
	   file_id,
	   record_id,
	   now() AS insert_date
FROM public.TEMP_deduped_orders
WHERE row_num = 1;
-- 25754

-- verifying the number of rows inserted
SELECT COUNT(*)
FROM public.orders;
-- 25754

SELECT COUNT(*)
FROM
(SELECT order_id, customer_id, order_date, count(*)
FROM public.stg_orders
GROUP BY order_id, customer_id, order_date) orders;
-- 25754

SELECT *
FROM public.orders
LIMIT 20;

-- Load the products table
-- Find all the unique products
-- For dupes of product_id/product_name, take the record that appears latest in the file
-- DROP TABLE public.TEMP_deduped_products
SELECT product_id,
	   product_name,
	   category,
	   subcategory,
	   file_id,
	   id AS record_id,
	   ROW_NUMBER() OVER(PARTITION BY product_id, product_name
						 ORDER BY id DESC) as "row_num"
INTO public.TEMP_deduped_products
FROM public.stg_orders;

INSERT INTO public.products (
	product_id,
	product_name,
	category,
	subcategory,
	file_id,
	record_id,
	insert_date)
SELECT product_id,
	   product_name,
	   category,
	   subcategory,
	   file_id,
	   record_id,
	   now() AS insert_date
FROM public.TEMP_deduped_products
WHERE row_num = 1;
-- 10768

-- verifying the number of rows inserted
SELECT COUNT(*)
FROM public.products;
-- 10768

SELECT COUNT(*)
FROM
(SELECT product_id, product_name, count(*)
FROM public.stg_orders
GROUP BY product_id, product_name) products;
-- 10768

SELECT *
FROM public.products
LIMIT 20;

-- Load the orders_products table
-- Find all the unique orders (order_id, customer_id, order_date, product_id, product_name)
-- For dupe orders, take the record that appears latest in the file
-- DROP TABLE public.TEMP_deduped_orders_products
SELECT order_id,
	   customer_id,
	   product_id,
	   order_date,
	   product_name,
	   quantity,
	   sales,
	   discount,
	   profit,
	   ship_date,
	   ship_mode,
	   ship_cost,
	   file_id,
	   id AS record_id,
	   ROW_NUMBER() OVER(PARTITION BY order_id, customer_id, order_date, product_id, product_name
						 ORDER BY row_id DESC) as "row_num"
INTO public.TEMP_deduped_orders_products
FROM public.stg_orders;

-- DROP TABLE public.TEMP_deduped_orders_products2
SELECT stg.*, ord.der_order_id, prd.der_product_id
INTO public.TEMP_deduped_orders_products2
FROM public.TEMP_deduped_orders_products stg
JOIN public.orders ord
ON stg.order_id = ord.order_id
AND stg.customer_id = ord.customer_id
AND stg.order_date = ord.order_date
JOIN public.products prd
ON stg.product_id = prd.product_id
AND stg.product_name = prd.product_name;

SELECT COUNT(*)
FROM public.TEMP_deduped_orders_products2
WHERE row_num > 1;
-- these are the dupes which will not be loaded

-- DROP TABLE public.orders_products;
INSERT INTO public.orders_products (
	   der_order_id,
	   der_product_id,
	   quantity,
	   sale_amt,
	   discount,
	   profit,
	   ship_date,
	   ship_mode,
	   ship_cost,
	   file_id,
	   record_id,
	   insert_date)
SELECT der_order_id,
	   der_product_id,
	   quantity,
	   sales,
	   discount,
	   profit,
	   ship_date,
	   ship_mode,
	   ship_cost,
	   file_id,
	   record_id,
	   now() AS insert_date
FROM public.TEMP_deduped_orders_products2
WHERE row_num = 1;
-- 51257

-- verifying the number of rows inserted
SELECT COUNT(*)
FROM public.orders_products;
-- 51257

SELECT COUNT(*)
FROM
(SELECT order_id, customer_id, order_date, product_id, product_name, count(*)
FROM public.stg_orders
GROUP BY order_id, customer_id, order_date, product_id, product_name) ordprd;
-- 51257

SELECT *
FROM public.orders_products
LIMIT 20;

SELECT COUNT(*)
FROM public.orders ord
JOIN public.orders_products ordprd
ON ord.der_order_id = ordprd.der_order_id
JOIN public.products prd
ON ordprd.der_product_id = prd.der_product_id
--51257;
