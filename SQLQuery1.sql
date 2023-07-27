---Inspecting data
select * from [dbo].[sales_data]

--Checking unique values
select distinct status from [dbo].[sales_data] ---plotting 
select distinct year_id from [dbo].[sales_data]
select distinct PRODUCTLINE from [dbo].[sales_data] ---plot
select distinct COUNTRY from [dbo].[sales_data] ---plot
select distinct DEALSIZE from [dbo].[sales_data] ---plot
select distinct TERRITORY from [dbo].[sales_data] ---plot

select distinct MONTH_ID from [dbo].[sales_data] ---As sales of 2005 are less we checked for whether the marketing was done for the whole year turns out it was only done for 5 months as compared to 12 months marketing in 2004 and 2003.
where YEAR_ID = 2005

---Analysis
---Starting with grouping sales by productline
select PRODUCTLINE, round(sum(sales),3) Revenue ---as we have used aggregate function sum we have to use group by
from [RfmDB].[dbo].[sales_data]
group by PRODUCTLINE
order by 2 desc

select YEAR_ID, round(sum(sales),3) Revenue ---as we have used aggregate function sum we have to use group by
from [RfmDB].[dbo].[sales_data]
group by YEAR_ID
order by 2 desc


select DEALSIZE, round(sum(sales),3) Revenue ---Medium size deals have the highest revenue
from [RfmDB].[dbo].[sales_data]
group by DEALSIZE
order by 2 desc


--Lets check for the best month for sales in a specific year.
select MONTH_ID, sum(sales) Revenue, count(ORDERNUMBER) Frequency
from [RfmDB].[dbo].[sales_data]
where YEAR_ID = 2004 --- change year to see the rest
group by MONTH_ID
order by 2 desc

--- november(11) was the best month for sales so let's see what product was sold in November
select MONTH_ID, PRODUCTLINE, sum(sales) Revenue, count(ORDERNUMBER) Total
from [RfmDB].[dbo].[sales_data]
where YEAR_ID = 2004 and MONTH_ID = 11 --- change year to see the rest
group by MONTH_ID, PRODUCTLINE
order by 3 desc --- order by 3rd (revenue) column


--- Who is our best customer(using Recency-Frequency-Monetary(RFM) analysis)
--- Recency = Last order date
--- Frequency = count of total orders
--- Monetary Value - total spend
DROP TABLE IF EXISTS #rfm;
with rfm as 
(
  select
	CUSTOMERNAME,
	sum(sales) MonetaryValue,
	avg(sales) AvgMonetaryValue,
	count(ORDERNUMBER) Frequency,
	max(ORDERDATE) last_order_date,
	(select max(ORDERDATE) from [dbo].[sales_data]) max_order_date,
	DATEDIFF(DD, max(ORDERDATE), (select max(ORDERDATE) from [dbo].[sales_data]))  Recency ---DD = date diffrence
  from[dbo].[sales_data]
  group by CUSTOMERNAME
),
rfm_calculation as 
(

	select r.*,
			NTILE(4) OVER(order by Recency desc) rfm_recency,
			NTILE(4) OVER(order by frequency) rfm_frequency,
			NTILE(4) OVER(order by MonetaryValue) rfm_monetary
	from rfm r
)
select c. *, rfm_recency + rfm_frequency + rfm_monetary as rfm_cell,---Concatenated
cast(rfm_recency as varchar) + cast(rfm_frequency as varchar) + cast(rfm_monetary as varchar)rfm_cell_string
into #rfm
from rfm_calculation c

select CUSTOMERNAME , rfm_recency , rfm_frequency , rfm_monetary,
	case	
		when rfm_cell_string in (111, 112, 121, 122, 123, 132, 211, 212, 114, 141) then 'lost_customers'
		when rfm_cell_string in (133, 134, 143, 244, 334, 343, 344, 144) then 'slipping away, cannot lose' ---(Big spenders who haven't purchased lately)
		when rfm_cell_string in (311, 411, 331) then 'new_customers'
		when rfm_cell_string in (222, 223, 233, 322) then 'potential churners'
		when rfm_cell_string in (323, 333, 321, 422, 332, 432) then 'active' --(Customers who buy often & recently but at low prices)
		when rfm_cell_string in (433, 434, 443, 444) then 'loyal' 
		end rfm_segment
from #rfm ---used as an object which can be called without running the whole query


--- lets look at the products that are most often sold together
	---select * from [dbo].[sales_data] where ORDERNUMBER = 10411
		
		select distinct ORDERNUMBER, stuff(

			(select ',' + PRODUCTCODE
			from [dbo].[sales_data] p
			where ORDERNUMBER in (
	
			select ORDERNUMBER
			from (

			select ORDERNUMBER, count(*) rowno
			FROM [dbo].[sales_data]
			where STATUS = 'Shipped'
			group by ORDERNUMBER
			)m
			where rowno = 2
			)
			and p.ORDERNUMBER = s.ORDERNUMBER

			for xml path (''))
			, 1, 1, '')Productcodes --- Stored priduct codes in XML path

			from [dbo].[sales_data] s
			order by 2 desc 
			--- ORDER NUMBER [10243,10409] and [10102,10256] purchased the same product when row number is 2.
			--- ORDER NUMBER 10236 and 10402 purchased the same product when row number is 3.