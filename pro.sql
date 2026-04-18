CREATE TABLE superstore (
    row_id INT,
    order_id VARCHAR,
    order_date DATE,
    ship_date DATE,
    ship_mode VARCHAR,
    customer_id VARCHAR,
    customer_name VARCHAR,
    segment VARCHAR,
    city VARCHAR,
    state VARCHAR,
    region VARCHAR,
    product_id VARCHAR,
    category VARCHAR,
    sub_category VARCHAR,
    sales NUMERIC
);
-- 1 customers
CREATE TABLE customers (
    customer_id VARCHAR PRIMARY KEY,
    customer_name VARCHAR,
    segment VARCHAR
);
INSERT INTO customers
SELECT DISTINCT customer_id, customer_name, segment
FROM superstore;
-- 2 orders
CREATE TABLE orders (
    order_id VARCHAR PRIMARY KEY,
    order_date DATE,
    ship_date DATE,
    ship_mode VARCHAR,
    customer_id VARCHAR,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);
INSERT INTO orders
SELECT DISTINCT order_id, order_date, ship_date, ship_mode, customer_id
FROM superstore;
-- 3 products
CREATE TABLE products (
    product_id VARCHAR PRIMARY KEY,
    category VARCHAR,
    sub_category VARCHAR
);
INSERT INTO products
SELECT DISTINCT product_id, category, sub_category
FROM superstore;
-- 4 locations
CREATE TABLE locations (
    location_id SERIAL PRIMARY KEY,
    city VARCHAR,
    state VARCHAR,
    region VARCHAR
);
INSERT INTO locations (city, state, region)
SELECT DISTINCT city, state, region
FROM superstore;
-- 5 order_details
CREATE TABLE order_details (
    row_id INT PRIMARY KEY,
    order_id VARCHAR,
    product_id VARCHAR,
    location_id INT,
    sales NUMERIC,

    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (location_id) REFERENCES locations(location_id)
);
INSERT INTO order_details (row_id, order_id, product_id, location_id, sales)
SELECT 
    s.row_id,
    s.order_id,
    s.product_id,
    l.location_id,
    s.sales
FROM superstore s
JOIN locations l
ON s.city = l.city
AND s.state = l.state
AND s.region = l.region;
	-- PROBLEMS
-- 1. Total Sales (Overall)
select round(sum(sales)) as total_sales
from order_details;

-- 2. What is the yearly trend of total sales over time?
-- Insight: are sales increasing each year → growth
with yearly as (  
  select  
    extract(year from o.order_date) as year,  
    sum(od.sales) as total_sales  
  from order_details od  
  join orders o on od.order_id = o.order_id  
  group by year  
)  
select  
  year,  
  total_sales,  
  coalesce(lag(total_sales) over(order by year), 0) as prev_year,  
  case  
    when lag(total_sales) over(order by year) is null then 0  
    else round(  
      (total_sales - lag(total_sales) over(order by year)) * 100.0 /  
      lag(total_sales) over(order by year),  
      2  
    )  
  end as growth_pct  
from yearly  
order by year;

-- 3. How many orders were placed each year?
-- Insight: Business growth (volume)
with yearly as (
  select 
    extract(year from order_date) as year,
    count(*) as total_orders
  from orders
  group by year
)
select 
  year,
  total_orders,
  coalesce(lag(total_orders) over(order by year), 0) as prev_orders,
  coalesce(
    round(
      (total_orders - lag(total_orders) over(order by year)) * 100.0 /
      lag(total_orders) over(order by year),
      2
    ), 0
  ) as growth_pct
from yearly
order by year;

-- 4. Which region generates the highest revenue?
-- Insight: Geographic performance
select l.region, round(sum(od.sales)) as total_sales
from order_details od
join locations l on od.location_id = l.location_id
group by l.region
order by total_sales desc;

-- 5. Which cities generate the highest total sales?
select 
  l.city,
  round(sum(od.sales), 2) as total_sales
from order_details od
join locations l on od.location_id = l.location_id
group by l.city
order by total_sales desc
limit 5;

-- 6. How do different shipping modes perform in terms of order volume, delivery time, and revenue?
select 
  o.ship_mode,
  count(distinct o.order_id) as total_orders,
  round(avg(o.ship_date - o.order_date), 2) as avg_delivery_days,
  round(sum(od.sales), 2) as total_sales
from orders o
join order_details od on o.order_id = od.order_id
group by o.ship_mode;

-- 7. Which product category drives most sales?
-- Insight: Product strategy
select p.category, round(sum(od.sales)) as total_sales
from products p
join order_details od
on p.product_id = od.product_id
group by p.category
order by total_sales desc;

-- 8. Which product sub category drives most sales?
-- Insight: Product strategy
select p.sub_category, round(sum(od.sales)) as total_sales
from products p
join order_details od
on p.product_id = od.product_id
group by p.sub_category
order by total_sales desc;

-- 9.Which sub-category products are purchased the most based on order count?

select 
  p.sub_category,
  count(*) as total_orders
from order_details od
join products p on od.product_id = p.product_id
group by p.sub_category
order by total_orders desc;

-- 10.Which sub-category generates the highest sales within each category?
-- Insight:
-- Identify the best-performing sub-category inside each category →
-- helps in product strategy and focus.
with base as (
  select
    p.category,
    p.sub_category,
    round(sum(od.sales)) as total_sales
  from order_details od
  join products p
    on p.product_id = od.product_id
  group by p.category, p.sub_category
),
ranked as (
  select *,
    rank() over (
      partition by category
      order by total_sales desc
    ) as rnk
  from base
)
select 
  category, 
  sub_category, 
  total_sales
from ranked
where rnk <= 2;

-- 11. Who are the most valuable customers?
-- Insight: Revenue concentration
with cte as
(select
o.customer_id, sum(od.sales) as total_sales
from order_details od
join orders o on od.order_id = o.order_id
group by o.customer_id
)
select customer_name, total_sales
from cte
join customers c on c.customer_id = cte.customer_id
order by total_sales desc
limit 5;

-- 12.Which customer segment (Consumer, Corporate, Home Office) pays more per order?
with order_totals as (
  select 
    o.order_id,
    c.segment,
    sum(od.sales) as order_value
  from orders o
  join order_details od on o.order_id = od.order_id
  join customers c on o.customer_id = c.customer_id
  group by o.order_id, c.segment
)

select 
  segment,
  count(order_id) as total_orders,
  round(avg(order_value), 2) as avg_order_value
from order_totals
group by segment
order by avg_order_value desc;

-- 13.Which product is most frequently sold in the top-performing cities?
with top_cities as (
select
l.city,
sum(od.sales) as city_sales
from order_details od
join locations l on od.location_id = l.location_id
group by l.city
order by city_sales desc
limit 5
),
city_products as (
select
l.city,
p.sub_category,
sum(od.sales) as total_sales,
row_number() over (
partition by l.city
order by sum(od.sales) desc
) as rn
from order_details od
join products p on od.product_id = p.product_id
join locations l on od.location_id = l.location_id
where l.city in (select city from top_cities)
group by l.city, p.sub_category
)
select
cp.city,
cp.sub_category,
cp.total_sales
from city_products cp
join top_cities tc on cp.city = tc.city
where cp.rn = 1
order by tc.city_sales desc;
-- 14.Which cities are underperforming and which sub-category products least sales in those cities?
with low_cities as (
select
l.city,
sum(od.sales) as city_sales
from order_details od
join locations l on od.location_id = l.location_id
group by l.city
order by city_sales asc
limit 5
),
city_products as (
select
l.city,
p.sub_category,
sum(od.sales) as total_sales,
row_number() over (
partition by l.city
order by sum(od.sales) asc
) as rn
from order_details od
join products p on od.product_id = p.product_id
join locations l on od.location_id = l.location_id
where l.city in (select city from low_cities)
group by l.city, p.sub_category
)
select
cp.city,
cp.sub_category,
cp.total_sales
from city_products cp
join low_cities tc on cp.city = tc.city
where cp.rn = 1
order by tc.city_sales asc;

