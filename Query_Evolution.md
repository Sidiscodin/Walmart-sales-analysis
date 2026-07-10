# Query Evolution — How I Got to the Final Solutions

This file walks through my thinking on the queries that took more than one attempt to get right. The main `Walmart_SQL_Queries.sql` file has the final, clean version of each — this is the "show your work" behind the ones that weren't obvious on the first try.

---

## Q3: Highest revenue-generating category per branch

**Attempt 1 — just the aggregation, no ranking:**
```sql
SELECT branch, category, ROUND(SUM(unit_price*quantity),2) AS total_rev
FROM walmart
GROUP BY branch, category
ORDER BY branch;
```
This gets me revenue per branch/category, but every branch has 6 rows (one per category) and I only want the top one. I need a way to rank *within* each branch.

**Attempt 2 — add RANK(), but can't filter yet:**
```sql
SELECT branch, category, ROUND(SUM(unit_price*quantity),2) AS total_rev,
       RANK() OVER(PARTITION BY branch ORDER BY SUM(unit_price*quantity) DESC) AS rnk
FROM walmart
GROUP BY branch, category
ORDER BY branch;
```
This is closer — `RANK() PARTITION BY branch` resets the ranking for every branch. But I can't add `WHERE rnk = 1` here directly, because window functions are evaluated *after* `WHERE` in SQL's execution order — you can't filter on a window function's own output in the same `SELECT`.

**Final — wrap it in a subquery so I can filter on `rnk`:**
```sql
SELECT branch, category, total_rev
FROM (
    SELECT branch, category, ROUND(SUM(unit_price*quantity),2) AS total_rev,
           RANK() OVER(PARTITION BY branch ORDER BY SUM(unit_price*quantity) DESC) AS rnk
    FROM walmart
    GROUP BY branch, category
) AS ranked
WHERE rnk = 1;
```
This is the pattern I reused for Q5 and Q6 as well — rank inside a subquery, filter outside it.

---

## Q7: Cities above average revenue

This one had the longest evolution — I went through four versions before landing on something I was happy with.

**Step 1 — get revenue per city:**
```sql
SELECT city, ROUND(SUM(unit_price*quantity),2) AS total_rev
FROM walmart
GROUP BY city;
```

**Step 2 — separately, get the average of those city totals:**
```sql
SELECT AVG(total_rev) AS avg_rev
FROM (
    SELECT city, ROUND(SUM(unit_price*quantity),2) AS total_rev
    FROM walmart GROUP BY city
) AS av;
```
I needed this as its own query first because `AVG(SUM(...))` isn't valid SQL directly — you can't nest an aggregate inside another aggregate in the same `GROUP BY` level, so the inner total has to be computed first, then averaged.

**Step 3 — combine them with a correlated subquery in WHERE:**
```sql
SELECT city, total_rev
FROM (SELECT city, ROUND(SUM(unit_price*quantity),2) AS total_rev FROM walmart GROUP BY city) AS av
WHERE total_rev > (
    SELECT AVG(total_rev) FROM (
        SELECT city, ROUND(SUM(unit_price*quantity),2) AS total_rev FROM walmart GROUP BY city
    ) AS cv
);
```
This works, but notice the city-revenue subquery is written out *twice* — once for the outer list of cities, once again inside the average calculation. Repeating logic like this is a maintenance risk: if I change the revenue formula later, I have to remember to change it in two places.

**Step 4 — collapse the outer subquery into HAVING:**
```sql
SELECT city, ROUND(SUM(unit_price*quantity),2) AS total_rev
FROM walmart
GROUP BY city
HAVING total_rev > (
    SELECT AVG(total_rev) FROM (
        SELECT city, ROUND(SUM(unit_price*quantity),2) AS total_rev FROM walmart GROUP BY city
    ) AS cv
);
```
Better — one less layer of nesting. But the average calculation still repeats the city-revenue logic a second time inside itself.

**Final — CTE so the city-revenue calculation only appears once:**
```sql
WITH city_revenue AS (
    SELECT city, ROUND(SUM(unit_price*quantity),2) AS total_revenue
    FROM walmart
    GROUP BY city
)
SELECT city, total_revenue
FROM city_revenue
WHERE total_revenue > (SELECT AVG(total_revenue) FROM city_revenue);
```
Now the revenue-per-city logic is defined once in the CTE and referenced twice — once for the row list, once inside the average. If the business ever redefines "revenue," I only change it in one place.

---

## Q8: Best and worst performing category by profit

**Attempt 1 — my first instinct, UNION of two separate queries:**
```sql
(SELECT category, ROUND(SUM(unit_price*quantity*profit_margin),2) AS profits
 FROM walmart GROUP BY category ORDER BY profits DESC LIMIT 1)
UNION
(SELECT category, ROUND(SUM(unit_price*quantity*profit_margin),2) AS profits
 FROM walmart GROUP BY category ORDER BY profits LIMIT 1);
```
This works, but it runs the aggregation twice — once for the top, once for the bottom — and it's brittle: it silently assumes there's more than one category, and the `LIMIT 1`s only make sense to a reader who already knows what the query is trying to do.

**Attempt 2 — rank once, but hardcode the bottom rank:**
```sql
WITH cat_rank AS (
    SELECT category, ROUND(SUM(unit_price*quantity*profit_margin),2) AS profits,
           RANK() OVER (ORDER BY SUM(unit_price*quantity*profit_margin) DESC) AS ranks
    FROM walmart GROUP BY category
)
SELECT category, profits FROM cat_rank WHERE ranks = 1 OR ranks = 6;
```
Only one aggregation pass now — better. But `ranks = 6` only works because I happen to know there are exactly 6 categories. If a 7th category got added tomorrow, this silently breaks and picks the wrong row.

**Final — rank both directions, filter without hardcoding anything:**
```sql
WITH category_profit AS (
    SELECT category, ROUND(SUM(unit_price*quantity*profit_margin),2) AS profits
    FROM walmart GROUP BY category
),
category_rank AS (
    SELECT *,
           RANK() OVER (ORDER BY profits DESC) AS desc_rank,
           RANK() OVER (ORDER BY profits ASC) AS asc_rank
    FROM category_profit
)
SELECT category, profits FROM category_rank
WHERE desc_rank = 1 OR asc_rank = 1;
```
`desc_rank = 1` is always the best regardless of how many categories exist, and `asc_rank = 1` is always the worst. This version doesn't need to know anything about the data ahead of time — it would still be correct with 3 categories or 30.

---

**The pattern across all three:** my first attempt usually got the right *answer*, but the final version is what I'd actually want running in production — less repeated logic, no hardcoded assumptions about the data, and easier for someone else to read six months later.
