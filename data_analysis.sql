-- data analysis to understand the granularity of the data

-- First check the Stage table
SELECT COUNT(*)
FROM public.stg_orders;
-- 51290 rows

-- Checking to see if any of the ID values are null
-- These records would need to be written to an error table or at least removed from stage
SELECT *
FROM public.temp_orders
WHERE order_id IS NULL
OR customer_id IS NULL
OR product_id IS NULL;
-- 0 rows

SELECT * FROM public.stg_orders
ORDER BY order_id, customer_id, order_date
LIMIT 100;

-- Let's determine what is on the product level
-- This would not change based on an order but could change over time
-- let's guess that a product is defined by a product_id
-- product_name, category, subcategory would seem to go with a product

-- let's see if we can have different product_name values for a given product_id
SELECT *
FROM public.stg_orders orders
JOIN
(SELECT product_id, COUNT(DISTINCT product_name)
FROM public.stg_orders
GROUP BY product_id
HAVING COUNT(DISTINCT product_name) > 1) dupes
ON orders.product_id = dupes.product_id
ORDER BY orders.product_id, orders.product_name;
-- product_name can vary for a given product_id
-- the primary key for product will be product_id and product_name

-- let's check category using our new primary key
SELECT product_id, product_name, COUNT(DISTINCT category)
FROM public.stg_orders
GROUP BY product_id, product_name
HAVING COUNT(DISTINCT category) > 1
-- category is distinct at the product_id/product_name level

-- let's check subcategory
SELECT product_id, product_name, COUNT(DISTINCT subcategory)
FROM public.stg_orders
GROUP BY product_id, product_name
HAVING COUNT(DISTINCT subcategory) > 1
-- subcategory is distinct at the product_id/product_name level

-- May be easiest to introduce an autoincrementing unique key for a product
-- to the products table
-- We can add this as a foreign key to the orders_products join table

-- Let's determine what is on the customer level
-- This would not change based on an order but could change over time
-- let's guess that a customer is defined by a customer_id
-- customer_name, segment, and market would seem to go with a customer
-- what about city and country?
-- let's see if we can have different product_name values for a given product_id
SELECT customer_id, COUNT(DISTINCT customer_name)
FROM public.stg_orders
GROUP BY customer_id
HAVING COUNT(DISTINCT customer_name) > 1;
-- customer_id looks like the correct primary key
-- each customer has a unique customer name

-- let's check segment
SELECT customer_id, COUNT(DISTINCT segment)
FROM public.stg_orders
GROUP BY customer_id
HAVING COUNT(DISTINCT segment) > 1;
-- segment is distinct at the customer_id level

-- let's check market
SELECT customer_id, COUNT(DISTINCT market)
FROM public.stg_orders
GROUP BY customer_id
HAVING COUNT(DISTINCT market) > 1;
-- market is distinct at the customer_id level

-- Let's determine what is on the order level
-- Is country at the customer level or at the order level?
select customer_id, count(distinct country)
from public.stg_orders
group by customer_id
having count(distinct country) > 1
-- So a customer can have multiple associated countries

-- Can an order have more than one associated country?
select order_id, count(distinct country)
from public.stg_orders
group by order_id
having count(distinct country) > 1
-- So an order can have more than one associated country

-- Can an order/customer combination have more than one associated country?
select order_id, customer_id, count(distinct country)
from public.stg_orders
group by order_id, customer_id
having count(distinct country) > 1
-- no

-- Let's take a look at the rows where there are multiple countries
-- associated with one order_id
select orders.*
from public.stg_orders orders
JOIN 
(select order_id, count(distinct country)
from public.stg_orders
group by order_id
having count(distinct country) > 1) dupes
on orders.order_id = dupes.order_id
ORDER BY orders.order_id, orders.country
-- one order_id can be associated with several countries,
-- customers, order_date values, sales, profit
-- It seems like an order/customer combination is what constitutes an order

-- can you have multiple order_priority values
-- associated with one order/customer combination?
SELECT order_id, customer_id, COUNT(DISTINCT order_priority)
from public.stg_orders
GROUP BY order_id, customer_id
HAVING COUNT(DISTINCT order_priority) > 1;
-- yes, you can!
-- it's only one order_id/customer_id combination so let's take a look

select *
from public.stg_orders
where order_id = 'ES-2014-1903302'
and customer_id = 'DG-133002';
-- one is Medium, one is High
-- appears that order_priority is at the order/customer/order_date level
-- order dates are different too

-- can one order/customer have multiple countries?
SELECT order_id, customer_id, COUNT(DISTINCT country)
from public.stg_orders
GROUP BY order_id, customer_id
HAVING COUNT(DISTINCT country) > 1;
-- no

-- can one order/customer have multiple cities?
SELECT order_id, customer_id, COUNT(DISTINCT city)
from public.stg_orders
GROUP BY order_id, customer_id
HAVING COUNT(DISTINCT city) > 1;
-- no

-- can one order/customer have multiple states?
SELECT order_id, customer_id, COUNT(DISTINCT state)
from public.stg_orders
GROUP BY order_id, customer_id
HAVING COUNT(DISTINCT state) > 1;
-- no

-- can one customer have multiple regions?
SELECT order_id, customer_id, COUNT(DISTINCT region)
from public.stg_orders
GROUP BY order_id, customer_id
HAVING COUNT(DISTINCT region) > 1;
-- no

-- can one order/customer combination have multiple order dates?
SELECT order_id, customer_id, COUNT(DISTINCT order_date)
from public.stg_orders
GROUP BY order_id, customer_id
HAVING COUNT(DISTINCT order_date) > 1;
-- yes
-- appears that order_date needs to be added to the key
-- so the key for an order would be order_id/customer_id/order_date

-- can one order have multiple ship dates?
SELECT order_id, customer_id, order_date, COUNT(DISTINCT ship_date)
from public.stg_orders
GROUP BY order_id, customer_id, order_date
HAVING COUNT(DISTINCT ship_date) > 1;
-- no

-- can one order have multiple ship modes?
SELECT order_id, customer_id, order_date, COUNT(DISTINCT ship_mode)
from public.stg_orders
GROUP BY order_id, customer_id, order_date
HAVING COUNT(DISTINCT ship_mode) > 1;
-- no

-- can one order have multiple ship cost?
SELECT order_id, customer_id, order_date, COUNT(DISTINCT ship_cost)
from public.stg_orders
GROUP BY order_id, customer_id, order_date
HAVING COUNT(DISTINCT ship_cost) > 1;
-- yes, so ship_cost appears to be at the order/product level
-- so we'll classify all three shipping fields at this level

-- Shipping columns - additional analysis
-- Is order_id, ship_date, ship_mode, ship_cost enough to identify a unique shipment?
-- These rows represent cases where there are multiple products being sent in one shipment
-- The shipping information is all the same between the rows with the same order_id
-- If we keep the shipping information on the order/product level then we will be 
-- double counting shipping cost for these 24 orders
SELECT orders.*
FROM public.stg_orders orders
JOIN 
(SELECT order_id, ship_date, ship_mode, ship_cost, count(*) 
FROM public.stg_orders
GROUP BY order_id, ship_date, ship_mode, ship_cost
HAVING count(*) > 1) dupes
ON dupes.ship_date = orders.ship_date
AND dupes.ship_mode = orders.ship_mode
AND dupes.ship_cost = orders.ship_cost
AND dupes.order_id = orders.order_id
ORDER by orders.ship_date, orders.ship_mode, orders.ship_cost, orders.order_id;


-- there can of course be multiple products included in each order
SELECT order_id, customer_id, order_date, COUNT(DISTINCT product_id)
FROM public.stg_orders
GROUP BY order_id, customer_id, order_date
HAVING COUNT(DISTINCT product_id) > 1

-- After analysis, here's what was found:
-- An order is defined as the combination of order_id/customer_id/order_date
-- Order level fields: priority, city, state, country, and region fields 

-- Order/Product level fields:
-- quantity, sale_amt, discount, profit, ship_date, ship_mode, ship_cost

-- order/product level and there isn't a shipping identifier so that 
-- this data can be split off to another table easily.
-- The rest of the fields on the orders table are at the order/customer/product 
-- level so it made sense to just put them all in one table instead of splitting 
-- them up.

-- verify that order/customer/order_date/product_id is the lowest level of granularity
select orders.*
from public.stg_orders orders
JOIN 
(SELECT order_id, customer_id, order_date, product_id, COUNT(*)
FROM public.stg_orders
GROUP BY order_id, customer_id, order_date, product_id
HAVING COUNT(*) > 1) dupes
ON orders.order_id = dupes.order_id
AND orders.customer_id = dupes.customer_id
AND orders.order_date = dupes.order_date
AND orders.product_id = dupes.product_id
ORDER BY orders.order_id, orders.customer_id, orders.order_date, orders.product_id, orders.row_id;
-- there are dupe rows where the profit, quantity, and ship_cost values differ
-- these do appear to be duplicates and not rows that should be counted distinctly
-- when we load the target tables we'll take the row with the largest row_id
