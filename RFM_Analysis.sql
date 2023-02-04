/* RFM Analysis 
We explore a sales dataset and generate various analytics and insights from 
customers' past purchase behavior. We go from analyzing sales revenue to creating 
a customer segmentation analysis using the RFM technique. We go from basic SQL 
queries to exploring complex problems using SUB QUERY, CTEs, AGGREGATE, and WINDOW functions.
We work on the following skills:
- Importing a file into SQL Server Database
- SQL Aggregate Functions
- SQL Window Functions
- SQL Sub Query
- Common Table Expressions (CTEs)
- MySQL group_concat Function
- Tableau
*/

create database sales_sample_data;
use sales_sample_data;
select * from sales;

alter table sales add column new_orderdate datetime;
select str_to_date(orderdate, "%m/%d/%Y"), new_orderdate from sales;
set sql_safe_updates = 0;
update sales
set new_orderdate = str_to_date(left(orderdate, 9),"%m/%d/%Y");
alter table sales drop column orderdate;
alter table sales rename column new_orderdate to ORDERDATE;


-- Checking for unique values
select distinct status from sales; -- nice to plot -- 6 groups
select distinct year_id from sales; -- 3 years 
select distinct productline from sales; -- nice to plot -- 7 productlines
select distinct country from sales; -- nice to plot -- market in 19 countries
select distinct territory from sales; -- nice to plot -- 4 territories
select distinct dealsize from sales; -- nice to plot -- 3 dealsize

-------- ANALYSIS -------
-- Let's start by grouping sales by productline.
select productline, sum(sales) as revenue
from sales
group by productline
order by 2 desc; -- classic cars has the highest revenue

-- year wise sales 
select year_id, sum(sales) as revenue
from sales
group by year_id
order by 2 desc; -- 2004 has the highest sales. But why is sales so less in 2005?

select year_id, month_id, sum(sales) as revenue
from sales
group by year_id,month_id
order by 1, 3 desc; -- year_wise monthly sales. We can see that in 2005 there are only 5 months 
						-- sales data. Maybe they could have performed better if they have operated 
                        -- for the entire year. Or maybe the dataset is not complete. 

-- dealwise sales
select dealsize, sum(sales) as revenue
from sales
group  by 1
order by 2 desc; -- medium deals has the highest sales followed by small deals. 
					-- So maybe they can focus on the medium sales more Or can come up with
                    -- some marketing schemes to focus on the small deals.

--  Which is the best month of sales in a specific year? How much is the sales?
select month_id, sum(sales) as revenue, count(ordernumber) as frequency
from sales
where year_id = 2003 -- change year to see the rest
group by month_id
order by 2 desc; -- really had a good order frequency in November for 2003 and 2004.
/* We are not considering 2005 as the data is till May and analysis will not be the true
reflection of the entire year */

select year_id, month_id, max(revenue) as highest_sales_month
from (select year_id, month_id, sum(sales) as revenue
from sales
group by year_id,month_id
order by 1, 3 desc) a
where year_id in (2003,2004)
group by year_id; -- For both 2003 and 2004 November has the highest revenue.   

-- November seems to the month. So let's see what product do they sell in November?
select month_id, productline, sum(sales) as revenue, count(ordernumber) as frequency
from sales
where year_id  = 2003 and month_id  =11 -- change year to see next
group by month_id, productline
order by 3 desc; -- (high)classic followed by vintage 

-- Who is the best customer?  ( this could be best answered with RFM )
drop temporary table rfm;
create temporary table rfm 
(
with rfm as
(
select 
	customername, 
    sum(sales) as Monetary_Value,
    avg(sales) as AvgMonetaryValue,
    count(ordernumber) as Frequency,
    max(orderdate) AS LastOrderDate,
    (select max(orderdate) from sales) max_order_date,
    datediff((select max(orderdate) from sales), max(orderdate)) as recency 
from sales
group by customername
),
rfm_calc as 
(
	select r.*,
		ntile(4) over (order by recency desc) rfm_recency,
		ntile(4) over (order by frequency) rfm_frequency,
		ntile(4) over (order by Monetary_Value) rfm_monetary
    from rfm r
    order by rfm_frequency desc
)
select c.*, rfm_recency + rfm_frequency + rfm_monetary as rfm_score,
concat(cast(rfm_recency as char), cast(rfm_frequency as char), cast(rfm_monetary as char)) as rfm_score_string
from rfm_calc c
);
select * from rfm;
select customername, recency, frequency, monetary_value, rfm_recency, rfm_frequency, rfm_monetary, rfm_score_string,
case 
	when rfm_score_string in (444, 434, 433, 443) then "Loyal"
    when rfm_score_string in (323, 333, 321, 422, 332, 432,331,421,412,423) then "Active" -- (Customers who buy often and recently, but low price points)
    when rfm_score_string in (222, 223, 233, 322,232) then "Potential Churners"
    when rfm_score_string in (411, 311,414,313) then "New Customers"
    when rfm_score_string in (133,134,143,244,334,343,344,144,312,234) then "Slipping away, cannot loose" -- (Big spenders who haevn't purchased lately)
	when rfm_score_string in (111,112,113,114,121,122,123,211, 212,141) then "Lost Customers" -- (Lost customers) 
    end as rfm_segment
from rfm;

-- What products are most often sold together? 

select ordernumber, count(1) as cnt
from sales
where status = "Shipped"
group by ordernumber; -- many orders are there against one ordernumber

-- select * from sales where ordernumber = 10107 order by ORDERLINENUMBER; -- this particulat customer has made 8 different products but on the same date

select p.ordernumber, group_concat(p.productcode) as products_sold from sales p
where p.ordernumber in
	(
		select ordernumber from
			(
				select ordernumber, count(1) as no_of_orders
				from sales a
				where status = "Shipped"
				group by ordernumber
			) s
		where no_of_orders = 2 -- change the value for more combined products
	) 
group by p.ordernumber
union all
select ordernumber, 'null' from sales pp
order by 2 desc;





