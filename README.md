# Walmart Sales Analytics Project – SQL

In this project, I stepped into the shoes of a data analyst for Walmart, working with a dataset of close to 10,000 transactions spread across 100 branches and 98 cities in the US, covering sales from 2019 to 2023. Each row captured a single transaction — the branch and city it happened in, the product category, unit price, quantity sold, date and time, payment method, customer rating, and profit margin.

My objective was to move past just "cleaning and looking at data" and actually answer the kind of questions a Walmart regional manager would ask: which branches are winning, which are lagging, when do people shop, how do they pay, and where is the profit actually coming from.

## Tools Used
- **MySQL** for querying and business analysis
- **Python (Pandas)** for data cleaning and loading into MySQL
- **SQLAlchemy + PyMySQL** to move the cleaned dataset from Python into a MySQL database

## The Process

I started by loading the raw CSV into Pandas, checking for duplicates and missing values, fixing the `unit_price` column (which had `$` symbols baked into it as text instead of numbers), and standardizing column names to lowercase before pushing the cleaned dataset into a MySQL database called `walmart_db` using SQLAlchemy.

From there, all the analysis happened in SQL.

- **I started with the basics** — total revenue, estimated profit, and transaction volume per branch, using `SUM()` and `COUNT()`. This gave me the big picture of which of the 100 branches were actually driving the business, and set up every question after it.

- **Next, I looked at how customers pay.** Grouping by `payment_method` and counting transactions showed the split between Cash, Credit Card, and Ewallet — useful for a business deciding where to invest in payment infrastructure.

- **Then I wanted to know each branch's strongest category.** This needed more than a simple `GROUP BY` — I used the `RANK()` window function partitioned by branch, ordered by revenue, and pulled out just the #1 category per branch from a subquery. This is the kind of "best X per group" question that comes up constantly in real analyst work.

- **I broke the day into Morning, Afternoon, and Evening shifts** using `CASE WHEN` on the `time` column, then counted transactions per shift per branch. This is a staffing and scheduling question in disguise — knowing when each branch is busiest tells you when to have more people on the floor.

- **I found the busiest day of the week for each branch**, extracting the day name from the `date` column with `DAYNAME()` and `STR_TO_DATE()`, then ranking days per branch the same way I ranked categories. Different branches turned out to peak on different days, which rules out a one-size-fits-all restocking schedule.

- **I identified the most preferred payment method per branch** — same `RANK()` pattern again, but this time partitioned by branch and payment method. Reusing the same window function logic across three different questions (Q3, Q5, Q6) was a deliberate choice: once you understand "rank within a group, then filter to rank = 1," it becomes a reusable tool rather than a one-off trick.

- **I found which cities out-earn the average city.** This one needed a subquery nested inside a `WHERE`/`HAVING` clause — first calculating revenue per city, then comparing each city's revenue against the average across all cities. I used a CTE (`WITH city_revenue AS (...)`) to keep the query readable instead of nesting subqueries three levels deep.

- **Finally, I found the best and worst performing product categories by total profit.** Rather than hardcoding `LIMIT 1` twice and `UNION`-ing the results (my first instinct), I ranked categories both ascending and descending by profit in a single CTE and filtered for rank = 1 on either side. This version doesn't break if the number of categories changes — a small thing, but the kind of detail that matters when data changes over time.

## Key Insights
- Branch performance varies significantly by both revenue and profit — the two don't always rank the same branch #1, which is worth flagging to leadership rather than assuming they move together.
- Category preference is genuinely branch-specific, not company-wide — a one-size-fits-all inventory strategy would underserve most locations.
- Shift and day-of-week patterns differ branch to branch, which argues against a uniform staffing schedule across the chain.
- A handful of cities significantly outperform the average, which is useful for deciding where to test new store formats or promotions first.

## Want to See My Thought Process?
The queries above are the final, clean solutions. For the trickier ones (Q3, Q7, Q8), I kept a record of the naive attempts that came before them and why each rewrite was an improvement — see [`Query_Evolution.md`](./Query_Evolution.md).

## What This Project Demonstrates
Aggregate functions, `GROUP BY`/`HAVING`, `CASE WHEN`, subqueries, CTEs, and the `RANK()` window function — applied to real business questions rather than syntax demos. The goal throughout wasn't "use every SQL feature" but "pick the right tool for each business question," which is closer to what the job actually looks like.

## Repository Structure
```
├── Walmart_data.csv              # Raw dataset
├── Clean_walmart_data.csv        # Cleaned dataset (post-Pandas)
├── Walmart_SQL_Queries.sql       # All business problems & SQL solutions
├── Query_Evolution.md            # Thought process behind the trickier queries
├── project.ipynb                 # Data cleaning + MySQL load (Python)
├── requirements.txt              # Python dependencies
└── README.md
```

## How to Run
1. Clone the repo and install dependencies: `pip install -r requirements.txt`
2. Run `project.ipynb` to clean the raw data and load it into a local MySQL database (update the connection string with your own credentials — never commit real passwords).
3. Run the queries in `Walmart_SQL_Queries.sql` against the `walmart_db` database in MySQL Workbench or any SQL client.
