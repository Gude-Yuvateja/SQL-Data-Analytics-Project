-- Advanced Data Analytics

-- 1. Change Over time analysis (TRENDS)

-- Analyze Sales Performance Over time 

SELECT 
	YEAR(Order_Date) AS Order_Year,
	MONTH(Order_Date) AS Order_Month,
	SUM(Sales_Amount) AS Total_Sales,
	COUNT(DISTINCT Customer_Key) AS Total_Coustomers,
	SUM(SAles_Quantity) AS Total_Quantity
FROM Gold.fact_sales
WHERE Order_Date IS NOT NULL
GROUP BY YEAR(Order_Date), MONTH(Order_Date)
ORDER BY YEAR(Order_Date), MONTH(Order_Date);



-- 2. Cumulative Analysis (Increasing or Decreasing to check)

-- Calculate the total sales per month
-- and the running total of sales over time

SELECT 
	Order_Date,
	Total_Sales,
	SUM(Total_Sales) OVER (ORDER BY Order_Date) AS Running_Total_Sales
FROM(
	SELECT 
		DATETRUNC(MONTH, Order_Date) AS Order_Date,
		SUM(Sales_Amount) AS Total_Sales
	FROM Gold.fact_sales
	WHERE Order_Date IS NOT NULL
	GROUP BY DATETRUNC(MONTH, Order_Date)
	) AS t;


-- Calculate the total sales per Year
-- and the running total of sales over time

SELECT 
	Order_Date,
	Total_Sales,
	SUM(Total_Sales) OVER (ORDER BY Order_Date) AS Running_Total_Sales
FROM(
	SELECT 
		DATETRUNC(YEAR, Order_Date) AS Order_Date,
		SUM(Sales_Amount) AS Total_Sales
	FROM Gold.fact_sales
	WHERE Order_Date IS NOT NULL
	GROUP BY DATETRUNC(YEAR, Order_Date)
	) AS t;




-- 3. Performance Analysis

/* Analyze the yearly performance pf products by comparing  their sales to both
   the Average sales performance of the product and the previous year's sales */

WITH Yearly_Product_Sales AS (
SELECT 
	YEAR(f.Order_Date) AS Order_Year,
	p.Product_Name,
	SUM(f.Sales_Amount) AS Current_Sales
FROM Gold.fact_sales AS f
LEFT JOIN Gold.dim_products AS p
ON f.Product_Key = p.Product_Key
WHERE f.Order_Date IS NOT NULL
GROUP BY YEAR(f.Order_Date), p.Product_Name
)
SELECT 
	Order_Year,
	Product_Name,
	Current_Sales,
	AVG(Current_Sales) OVER ( PARTITION BY Product_Name) AS Avg_sales,
	Current_Sales - AVG(Current_Sales) OVER ( PARTITION BY Product_Name) AS Diff_Avg,
	CASE WHEN Current_Sales - AVG(Current_Sales) OVER ( PARTITION BY Product_Name) > 0 THEN 'Above Avg'
		 WHEN Current_Sales - AVG(Current_Sales) OVER ( PARTITION BY Product_Name) < 0 THEN 'Below Avg'
		 ELSE 'Avg'
	END AS Avg_Change,
	LAG(Current_Sales) OVER (PARTITION BY Product_Name ORDER BY Order_Year) AS PY_Sales,
	Current_Sales - LAG(Current_Sales) OVER (PARTITION BY Product_Name ORDER BY Order_Year) AS Diff_PY,
	CASE WHEN Current_Sales - LAG(Current_Sales) OVER (PARTITION BY Product_Name ORDER BY Order_Year) > 0 THEN 'Increase'
		 WHEN Current_Sales - LAG(Current_Sales) OVER (PARTITION BY Product_Name ORDER BY Order_Year) < 0 THEN 'Decrease'
		 ELSE 'No Change'
	END AS PY_Change
FROM Yearly_Product_Sales
ORDER BY Product_Name, Order_Year;




-- 4. Part-to-whole Analysis

-- Which categories contribute the most to overall sales?

WITH Category_Sales AS (
SELECT 
	p.Category,
	SUM(f.Sales_Amount) AS Total_Sales
FROM Gold.fact_sales AS f
LEFT JOIN Gold.dim_products AS p
ON f.Product_Key = p.Product_Key
GROUP BY Category
)
SELECT 
	Category,
	Total_Sales,
	SUM(Total_Sales) OVER () AS Overall_Sales,
	CONCAT(ROUND((CAST(Total_Sales AS FLOAT)/SUM(Total_Sales) OVER ())*100,2), '%') AS Percentage_of_Total
FROM Category_Sales
ORDER BY Percentage_of_Total DESC;





-- 5. Data Segementation

/* Segmnet products into cost ranges and count
   How many products fall into each segment */

WITH Product_Segments AS (
SELECT 
	Product_Key,
	Product_Name,
	Product_Cost,
	CASE WHEN Product_Cost < 100 THEN 'Below 100'
		 WHEN Product_Cost BETWEEN 100 AND 500 THEN '100-500'
		 WHEN Product_Cost BETWEEN 500 AND 1000 THEN '600-1000'
		 ELSE 'Above 1000'
	END AS Cost_Range
FROM Gold.dim_products
)
SELECT 
	Cost_Range,
	COUNT(Product_Key) AS Total_Products
FROM Product_Segments
GROUP BY Cost_Range
ORDER BY Total_Products DESC;



/* Group customers into three segments based on their spending behavior :
 - VIP : Customers with at least 12 months of history and spending more than $5,000.
 - Regular : Customers with at least 12 months of history but Spending $5,000 or Less.
 - New : Customers with a lifespan less than 12 months.
 And find the total no of customers by each group. */


WITH Customer_Spending AS (
SELECT 
	c.Customer_Key,
	SUM(f.Sales_Amount) AS Total_Spending,
	MIN(Order_Date) AS First_Order,
	MAX(Order_Date) AS Last_Order,
	DATEDIFF(MONTH, MIN(Order_Date), MAX(Order_Date)) AS Lifespan
FROM Gold.fact_sales AS f
LEFT JOIN Gold.dim_customers AS c
ON f.Customer_Key = c.Customer_Key
GROUP BY c.Customer_Key
)
SELECT 
	Customer_segment,
	COUNT(Customer_Key) AS Total_Customers
FROM (
SELECT 
	Customer_Key,
	CASE WHEN Lifespan >= 12 AND Total_Spending > 5000 THEN 'VIP'
		 WHEN Lifespan >= 12 AND Total_Spending <= 5000 THEN 'REGULAR'
		 ELSE 'NEW'
	END AS Customer_segment
FROM Customer_Spending) AS t
GROUP BY Customer_Segment
ORDER BY Total_Customers DESC;





-- 6. Reporting 

/*
	===============================================================================
	Customer Report
	===============================================================================
	Purpose:
		- This report consolidates key customer metrics and behaviors

	Highlights:
		1. Gathers essential fields such as names, ages, and transaction details.
		2. Segments customers into categories (VIP, Regular, New) and age groups.
		3. Aggregates customer-level metrics:
		   - total orders
		   - total sales
		   - total quantity purchased
		   - total products
		   - lifespan (in months)
		4. Calculates valuable KPIs:
			- recency (months since last order)
			- average order value
			- average monthly spend
	=============================================================================== 
*/

IF OBJECT_ID('Gold.report_customers', 'V') IS NOT NULL
	DROP VIEW Gold.report_customers;
GO

CREATE VIEW Gold.report_customers AS 
-- =============================================================================
-- Create Report: gold.report_customers
-- =============================================================================

WITH Base_Query AS (
/*---------------------------------------------------------------------------
1) Base Query: Retrieves core columns from tables
---------------------------------------------------------------------------*/
SELECT 
	f.Order_Number,
	f.Product_Key,
	f.Order_Date,
	f.Sales_Amount,
	f.Sales_Quantity,
	c.Customer_Key,
	c.Customer_Number,
	CONCAT(C.First_Name, ' ', c.Last_Name) AS Customer_Name,
	DATEDIFF(YEAR, c.Birth_Date, GETDATE()) AS Age
FROM Gold.fact_sales AS f
LEFT JOIN Gold.dim_customers AS c
ON f.Customer_Key = c.Customer_Key
WHERE Order_Date IS NOT NULL
)
, Customer_Aggregation AS (
/*---------------------------------------------------------------------------
2) Customer Aggregations: Summarizes key metrics at the customer level
---------------------------------------------------------------------------*/
SELECT 
	Customer_Key,
	Customer_Number,
	Customer_Name,
	Age,
	COUNT(DISTINCT Order_Number) AS Total_Orders,
	SUM(Sales_Amount) AS Total_Sales,
	COUNT(DISTINCT Product_Key) AS Total_Products,
	MAX(Order_Date) AS Last_Order_Date,
	DATEDIFF(MONTH, MIN(Order_Date), MAX(Order_Date)) AS Lifespan
FROM Base_Query
GROUP BY Customer_Key,
		 Customer_Number,
		 Customer_Name,
		 Age
)
SELECT 
	Customer_Key,
	Customer_Number,
	Customer_Name,
	Age,
	CASE WHEN Age < 20 THEN 'Under 20'
		 WHEN Age BETWEEN 20 AND 29 THEN '20-29'
		 WHEN Age BETWEEN 30 AND 39 THEN '30-39'
		 WHEN Age BETWEEN 40 AND 49 THEN '40-49'
		 WHEN Age BETWEEN 50 AND 59 THEN '50-59'
		 ELSE 'Above 60'
	END AS Age_Group,
	CASE WHEN Lifespan >= 12 AND Total_Sales > 5000 THEN 'VIP'
		 WHEN Lifespan >= 12 AND Total_Sales <= 5000 THEN 'REGULAR'
		 ELSE 'NEW'
	END AS Customer_segment,
	Last_Order_Date,
	DATEDIFF(MONTH, Last_Order_Date, GETDATE()) AS Recency,
	Total_Orders,
	Total_Sales,
	Total_Products,
	Lifespan,
-- Compuate average order value (AVO)
	CASE WHEN Total_Sales = 0 THEN 0
		 ELSE Total_Sales / Total_Orders 
	END AS Avg_Order_Value,
-- Compuate average monthly spend
	CASE WHEN Lifespan = 0 THEN 0
		 ELSE Total_Sales / Lifespan
	END AS Avg_Monthly_Spend
FROM Customer_Aggregation;




/*
	===============================================================================
	Product Report
	===============================================================================
	Purpose:
		- This report consolidates key product metrics and behaviors.

	Highlights:
		1. Gathers essential fields such as product name, category, subcategory, and cost.
		2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
		3. Aggregates product-level metrics:
		   - total orders
		   - total sales
		   - total quantity sold
		   - total customers (unique)
		   - lifespan (in months)
		4. Calculates valuable KPIs:
		   - recency (months since last sale)
		   - average order revenue (AOR)
		   - average monthly revenue
	===============================================================================
*/

IF OBJECT_ID ('Gold.report_products', 'V') IS NOT NULL
	DROP VIEW Gold.report_products;
GO

CREATE VIEW Gold.report_products AS 
-- =============================================================================
-- Create Report: gold.report_products
-- =============================================================================

WITH Base_Query AS ( 
/*---------------------------------------------------------------------------
1) Base Query: Retrieves core columns from fact_sales and dim_products
---------------------------------------------------------------------------*/
SELECT 
	f.Order_Number,
	f.Customer_Key,
	f.Order_Date,
	f.Sales_Amount,
	f.Sales_Quantity,
	p.Product_Key,
	p.Product_Name,
	p.Category,
	p.Sub_Category,
	p.Product_Cost
FROM Gold.fact_Sales AS f
LEFT JOIN Gold.dim_products AS p
ON f.Product_Key =p.Product_Key
WHERE Order_Date IS NOT NULL   -- Only consider valid sales dates
),
Product_Aggregation AS (
/*---------------------------------------------------------------------------
2) Product Aggregations: Summarizes key metrics at the product level
---------------------------------------------------------------------------*/
SELECT 
	Product_Key,
	Product_Name,
	Category,
	Sub_Category,
	Product_Cost,
	DATEDIFF(YEAR, MIN(Order_Date), MAX(Order_Date)) AS Lifespan,
	MAX(Order_Date) AS Last_Order_Date,
	COUNT(DISTINCT Order_Number) AS Total_Orders,
	COUNT(DISTINCT Customer_Key) AS Total_Customers,
	SUM(Sales_Amount) As Total_Sales,
	SUM(Sales_Quantity) AS Total_Quantity,
	ROUND(AVG(CAST(Sales_Amount AS FLOAT) / NULLIF(Sales_Quantity, 0)), 2) AS Avg_Selling_Price
FROM Base_Query
GROUP BY Product_Key,
		 Product_Name,
		 Category,
		 Sub_Category,
		 Product_Cost
)
/*---------------------------------------------------------------------------
  3) Final Query: Combines all product results into one output
---------------------------------------------------------------------------*/
SELECT 
	Product_Key,
	Product_Name,
	Category,
	Sub_Category,
	Product_Cost,
	Last_Order_Date,
	DATEDIFF(MONTH, Last_Order_Date, GETDATE()) AS Recency_In_Months,
	CASE WHEN Total_Sales > 50000 THEN 'High-Performance'
		 WHEN Total_Sales >= 10000 THEN 'Mid-Range'
		 ELSE 'Low-Performance'
	END AS Product_Segment,
	Lifespan,
	Total_Orders,
	Total_Customers,
	Total_Sales,
	Total_Quantity,
	Avg_Selling_Price,
-- Average Order Revenue (AOR)
	CASE WHEN Total_Sales = 0 THEN 0
		 ELSE Total_Sales / Total_Orders
	END AS Avg_Order_Revenue,
-- Average Monthly Revenue (AMR)
	CASE WHEN Lifespan = 0 THEN Total_Sales
		 ELSE Total_Sales / Lifespan
	END AS Avg_Monthly_Revenue
FROM Product_Aggregation;