
-- -- -- -- -- -- -- RFM -- -- -- -- -- -- -- 
CREATE VIEW vw_RFM_Analysis AS
WITH RFM_Base AS
(
  SELECT 
    b.customer_id AS CustomerID, 
    b.name AS CustomerName,
    DATEDIFF(DAY, MAX(a.transaction_date), CAST(GETDATE() AS DATE)) AS Recency_Value,
    COUNT(DISTINCT a.transaction_date) AS Frequency_Value,
    ROUND(SUM(a.Revenue), 2) AS Monetary_Value
  FROM Transactions1 AS a
  INNER JOIN CustomerDemographic AS b 
  ON a.customer_id = b.customer_id
  GROUP BY b.customer_id, b.name
),
RFM_Score AS
(
  SELECT *,
    NTILE(5) OVER (ORDER BY Recency_Value DESC) AS R_Score,
    NTILE(5) OVER (ORDER BY Frequency_Value ASC) AS F_Score,
    NTILE(5) OVER (ORDER BY Monetary_Value ASC) AS M_Score
  FROM RFM_Base
),
RFM_Final AS
(
  SELECT *,
    CONCAT(R_Score, F_Score, M_Score) AS RFM_Overall
  FROM RFM_Score
)
SELECT f.*, s.Segment
FROM RFM_Final f
JOIN [segmentscores] s 
ON f.RFM_Overall = s.Scores;

-- -- -- -- -- -- -- New/Existing -- -- -- -- -- -- -- 
WITH t1 AS(
	SELECT MONTH(transaction_date) AS tran_month, customer_id
			, RANK() OVER (PARTITION BY customer_id ORDER BY transaction_date)  isnew
	FROM Transactions1
),
t2 AS (
SELECT *
	   , CASE WHEN isnew = 1 THEN 'New' ELSE 'Existing' END Customer_Type 
FROM t1
),
t3 AS (
SELECT tran_month
		, COUNT(DISTINCT customer_id) NoCustomer
FROM t2
where isnew = 1
GROUP BY tran_month
),
t4 AS (
	SELECT MONTH(transaction_date) AS tran_month
			, COUNT(DISTINCT Customer_id) AS Total
	FROM Transactions1
	GROUP BY MONTH(transaction_date)
)
SELECT t3.tran_month, t3.NoCustomer, t4.Total
FROM t3
LEFT JOIN t4 ON t3.tran_month = t4.tran_month
ORDER BY t3.tran_month



-- -- -- -- -- -- -- Cohort -- -- -- -- -- -- -- 
WITH t1 AS(
	SELECT transaction_id, MONTH(transaction_date) AS tran_month, customer_id
			, MIN( MONTH(transaction_date)) OVER (PARTITION BY customer_id)  first_month
	FROM Transactions1
),
t2 AS (
	SELECT *
		 , tran_month - first_month as time_frame
	FROM t1
), 
t3 AS (
SELECT first_month, time_frame
		, COUNT(DISTINCT customer_id) AS retained_customers
FROM t2
GROUP BY first_month, time_frame
)
SELECT * 
	, CAST(retained_customers AS DECIMAL) /	MAX(retained_customers) OVER (PARTITION BY first_month) AS retained_rate
FROM t3
ORDER BY first_month, time_frame


