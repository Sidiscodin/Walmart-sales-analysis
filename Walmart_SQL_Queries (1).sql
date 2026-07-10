-- ============================================================
-- Walmart Sales Data Analysis — SQL Business Problems & Solutions
-- Author: Siddharth
-- Tool: MySQL 8+
-- Dataset: ~9,969 transactions | 100 branches | 98 cities | 2019-2023
-- ============================================================

SHOW DATABASES;
USE walmart_db;

SELECT * FROM walmart LIMIT 5;
SELECT COUNT(*) FROM walmart;
SELECT COUNT(DISTINCT branch) FROM walmart;


/* ============================================================
   Q1: Analyze the total revenue, estimated profit, and
   transaction volume across branches to identify the
   best-performing locations.
   ============================================================ */
SELECT
    branch,
    city,
    COUNT(*) AS total_transactions,
    ROUND(SUM(unit_price * quantity), 2) AS total_revenue,
    ROUND(SUM(unit_price * quantity * profit_margin), 2) AS total_profit
FROM walmart
GROUP BY branch, city
ORDER BY total_revenue DESC;


/* ============================================================
   Q2: Analyze the distribution of customer payment methods
   across all transactions.
   ============================================================ */
SELECT
    payment_method,
    COUNT(*) AS total_transactions,
    ROUND(SUM(unit_price * quantity), 2) AS total_transaction_amount
FROM walmart
GROUP BY payment_method
ORDER BY total_transactions DESC;


/* ============================================================
   Q3: Identify the highest revenue-generating product category
   in each branch.
   ============================================================ */
SELECT branch, category, total_revenue
FROM (
    SELECT
        branch,
        category,
        ROUND(SUM(unit_price * quantity), 2) AS total_revenue,
        RANK() OVER (PARTITION BY branch ORDER BY SUM(unit_price * quantity) DESC) AS rnk
    FROM walmart
    GROUP BY branch, category
) AS ranked
WHERE rnk = 1
ORDER BY branch;


/* ============================================================
   Q4: Analyze the distribution of customer transactions across
   Morning, Afternoon, and Evening shifts for each branch.
   ============================================================ */
SELECT
    branch,
    CASE
        WHEN HOUR(time) < 12 THEN 'Morning'
        WHEN HOUR(time) >= 12 AND HOUR(time) < 17 THEN 'Afternoon'
        ELSE 'Evening'
    END AS shift,
    COUNT(*) AS total_transactions
FROM walmart
GROUP BY branch, shift
ORDER BY branch, total_transactions DESC;


/* ============================================================
   Q5: Identify the busiest day of the week for each branch
   based on number of transactions.
   ============================================================ */
SELECT branch, day AS busiest_day, trans_count
FROM (
    SELECT
        branch,
        DAYNAME(STR_TO_DATE(date, '%d/%m/%y')) AS day,
        COUNT(*) AS trans_count,
        RANK() OVER (PARTITION BY branch ORDER BY COUNT(*) DESC) AS rnk
    FROM walmart
    GROUP BY branch, day
) AS ranked
WHERE rnk = 1
ORDER BY branch;


/* ============================================================
   Q6: Identify the most preferred payment method for each
   branch based on number of transactions.
   ============================================================ */
SELECT branch, payment_method, trans_count
FROM (
    SELECT
        branch,
        payment_method,
        COUNT(*) AS trans_count,
        RANK() OVER (PARTITION BY branch ORDER BY COUNT(*) DESC) AS rnk
    FROM walmart
    GROUP BY branch, payment_method
) AS ranked
WHERE rnk = 1
ORDER BY branch;


/* ============================================================
   Q7: Identify the cities whose total revenue is higher than
   the average revenue generated across all cities.
   ============================================================ */
WITH city_revenue AS (
    SELECT
        city,
        ROUND(SUM(unit_price * quantity), 2) AS total_revenue
    FROM walmart
    GROUP BY city
)
SELECT city, total_revenue
FROM city_revenue
WHERE total_revenue > (SELECT AVG(total_revenue) FROM city_revenue)
ORDER BY total_revenue DESC;


/* ============================================================
   Q8: Identify the best-performing and worst-performing product
   categories based on total profit generated.
   ============================================================ */
WITH category_profit AS (
    SELECT
        category,
        ROUND(SUM(unit_price * quantity * profit_margin), 2) AS profits
    FROM walmart
    GROUP BY category
),
category_rank AS (
    SELECT
        *,
        RANK() OVER (ORDER BY profits DESC) AS desc_rank,
        RANK() OVER (ORDER BY profits ASC) AS asc_rank
    FROM category_profit
)
SELECT category, profits
FROM category_rank
WHERE desc_rank = 1 OR asc_rank = 1
ORDER BY profits DESC;
