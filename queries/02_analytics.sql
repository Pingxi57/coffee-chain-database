-- =====================================================================
-- Phase 3 — 02 Business analytics queries
-- Run after 01_views.sql.
--
-- Each query answers one business question and shows one or more
-- advanced SQL techniques:
--   Q1  Monthly revenue, growth % and year-to-date total   CTE, LAG, SUM() OVER (PARTITION BY)
--   Q2  7-day moving average of daily orders               window frame ROWS BETWEEN
--   Q3  Branch ranking and 80/20 (Pareto) share            RANK, running SUM() OVER
--   Q4  Top 3 products in each branch                      DENSE_RANK() OVER (PARTITION BY)
--   Q5  Busiest hour of each branch                        ROW_NUMBER, conditional aggregation
--   Q6  RFM customer segmentation                          chained CTEs, NTILE
--   Q7  Customers at risk of churning                      LAG on dates, per-customer averages
--   Q8  Monthly cohort retention                           CTE, MIN() OVER, pivot with SUM(CASE)
--   Q9  Did promotions increase spending?                  CTE comparison, ratios
--   Q10 Products most often bought together                self-join
--   Q11 Median delivery time per branch                    ROW_NUMBER + COUNT() OVER (median)
--   Q12 Unusually quiet days per branch                    RECURSIVE CTE calendar, CROSS/LEFT JOIN
--
-- The dataset ends on 2026-09-30, so "today" is fixed here for repeatable results.
-- =====================================================================
USE coffee_chain_db;
SET NAMES utf8mb4;   -- make sure accented names (Caffè, Açaí) are stored correctly
SET @as_of = DATE('2026-09-30');


-- ---------------------------------------------------------------------
-- Q1. How is revenue growing month by month, and what is the total so far this year?
--     LAG() reads the previous month's value, and SUM() OVER (PARTITION BY year)
--     restarts the running total every January.
-- ---------------------------------------------------------------------
WITH monthly AS (
    SELECT DATE_FORMAT(p.Paid_At, '%Y-%m') AS Month,
           YEAR(p.Paid_At)                 AS Yr,
           COUNT(*)                        AS Paid_Orders,
           SUM(p.Amount)                   AS Revenue
    FROM Payment p
    WHERE p.Payment_Status = 'Success'
    GROUP BY DATE_FORMAT(p.Paid_At, '%Y-%m'), YEAR(p.Paid_At)
)
SELECT Month,
       Paid_Orders,
       Revenue,
       LAG(Revenue) OVER (ORDER BY Month)                                   AS Prev_Month_Revenue,
       ROUND(100 * (Revenue - LAG(Revenue) OVER (ORDER BY Month))
                 / LAG(Revenue) OVER (ORDER BY Month), 1)                   AS Growth_Pct,
       SUM(Revenue) OVER (PARTITION BY Yr ORDER BY Month)                   AS YTD_Revenue
FROM monthly
ORDER BY Month;


-- ---------------------------------------------------------------------
-- Q2. What is the underlying trend in daily orders (smoothing out day-to-day noise)?
--     A 7-day moving average uses a window frame of the current row + 6 rows before it.
--     Shown for the last 60 days.
-- ---------------------------------------------------------------------
WITH daily AS (
    SELECT DATE(Order_DateTime) AS Day, COUNT(*) AS Orders
    FROM Orders
    WHERE Order_Status <> 'Cancelled'
      AND Order_DateTime >= @as_of - INTERVAL 66 DAY
      AND Order_DateTime <  @as_of + INTERVAL 1 DAY
    GROUP BY DATE(Order_DateTime)
)
SELECT Day,
       DAYNAME(Day) AS Weekday,
       Orders,
       ROUND(AVG(Orders) OVER (ORDER BY Day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 1) AS Moving_Avg_7d
FROM daily
ORDER BY Day DESC
LIMIT 60;


-- ---------------------------------------------------------------------
-- Q3. Which branches bring in the most money, and do a few branches make most of it?
--     Running SUM() OVER (ORDER BY revenue DESC) gives the cumulative share (Pareto / 80-20).
--     Last 12 months.
-- ---------------------------------------------------------------------
WITH branch_rev AS (
    SELECT o.Branch_ID, b.Branch_Name, b.Store_Type,
           COUNT(*)      AS Orders,
           SUM(p.Amount) AS Revenue
    FROM Orders o
    JOIN Payment p ON p.Order_ID = o.Order_ID AND p.Payment_Status = 'Success'
    JOIN Branch b  ON b.Branch_ID = o.Branch_ID
    WHERE o.Order_DateTime >= @as_of - INTERVAL 12 MONTH
    GROUP BY o.Branch_ID, b.Branch_Name, b.Store_Type
)
SELECT RANK() OVER (ORDER BY Revenue DESC)                                    AS Rnk,
       Branch_Name,
       Store_Type,
       Orders,
       Revenue,
       ROUND(100 * Revenue / SUM(Revenue) OVER (), 2)                         AS Share_Pct,
       ROUND(100 * SUM(Revenue) OVER (ORDER BY Revenue DESC
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                 / SUM(Revenue) OVER (), 1)                                   AS Cumulative_Share_Pct
FROM branch_rev
ORDER BY Rnk;


-- ---------------------------------------------------------------------
-- Q4. What are the top 3 best-selling products in each branch? (last 6 months)
--     DENSE_RANK() restarts at 1 for every branch (PARTITION BY Branch_ID).
-- ---------------------------------------------------------------------
WITH branch_product AS (
    SELECT o.Branch_ID, i.Product_ID, SUM(i.Quantity) AS Units
    FROM Orders o
    JOIN Order_Item i ON i.Order_ID = o.Order_ID
    WHERE o.Order_Status <> 'Cancelled'
      AND o.Order_DateTime >= @as_of - INTERVAL 6 MONTH
    GROUP BY o.Branch_ID, i.Product_ID
),
ranked AS (
    SELECT bp.*,
           DENSE_RANK() OVER (PARTITION BY bp.Branch_ID ORDER BY bp.Units DESC) AS Rank_In_Branch
    FROM branch_product bp
)
SELECT b.Branch_Name, r.Rank_In_Branch, p.Product_Name, r.Units
FROM ranked r
JOIN Branch b  ON b.Branch_ID = r.Branch_ID
JOIN Product p ON p.Product_ID = r.Product_ID
WHERE r.Rank_In_Branch <= 3
ORDER BY b.Branch_ID, r.Rank_In_Branch, p.Product_Name;


-- ---------------------------------------------------------------------
-- Q5. When is each branch busiest? (for staff scheduling)
--     Part A: busiest hour per branch using ROW_NUMBER().
--     Part B: hour-by-day-part "pivot" for the whole chain using SUM(CASE ...).
-- ---------------------------------------------------------------------
WITH hourly AS (
    SELECT Branch_ID, HOUR(Order_DateTime) AS Hr, COUNT(*) AS Orders
    FROM Orders
    WHERE Order_DateTime >= @as_of - INTERVAL 3 MONTH
    GROUP BY Branch_ID, HOUR(Order_DateTime)
),
ranked AS (
    SELECT h.*,
           ROW_NUMBER() OVER (PARTITION BY Branch_ID ORDER BY Orders DESC, Hr) AS rn,
           SUM(Orders)  OVER (PARTITION BY Branch_ID)                          AS Branch_Total
    FROM hourly h
)
SELECT b.Branch_Name,
       CONCAT(LPAD(r.Hr, 2, '0'), ':00-', LPAD(r.Hr + 1, 2, '0'), ':00') AS Busiest_Hour,
       r.Orders AS Orders_In_That_Hour,
       ROUND(100 * r.Orders / r.Branch_Total, 1)                        AS Pct_Of_Branch_Orders
FROM ranked r
JOIN Branch b ON b.Branch_ID = r.Branch_ID
WHERE r.rn = 1
ORDER BY r.Orders DESC;

-- Part B: weekday vs weekend by part of day
SELECT CASE WHEN DAYOFWEEK(Order_DateTime) IN (1, 7) THEN 'Weekend' ELSE 'Weekday' END AS Day_Type,
       SUM(CASE WHEN HOUR(Order_DateTime) < 11                 THEN 1 ELSE 0 END) AS Morning_before_11,
       SUM(CASE WHEN HOUR(Order_DateTime) BETWEEN 11 AND 13    THEN 1 ELSE 0 END) AS Lunch_11_14,
       SUM(CASE WHEN HOUR(Order_DateTime) BETWEEN 14 AND 16    THEN 1 ELSE 0 END) AS Afternoon_14_17,
       SUM(CASE WHEN HOUR(Order_DateTime) >= 17                THEN 1 ELSE 0 END) AS Evening_17_plus,
       COUNT(*) AS Total
FROM Orders
WHERE Order_DateTime >= @as_of - INTERVAL 3 MONTH
GROUP BY Day_Type;


-- ---------------------------------------------------------------------
-- Q6. Who are our best, loyal, and slipping customers? (RFM segmentation)
--     R = days since last order, F = number of orders, M = money spent.
--     NTILE(5) splits customers into 5 equal groups for each measure (5 = best).
-- ---------------------------------------------------------------------
WITH rfm_raw AS (
    SELECT o.Member_ID,
           DATEDIFF(@as_of, MAX(o.Order_DateTime)) AS Recency_Days,
           COUNT(*)                                AS Frequency,
           SUM(p.Amount)                           AS Monetary
    FROM Orders o
    JOIN Payment p ON p.Order_ID = o.Order_ID AND p.Payment_Status = 'Success'
    GROUP BY o.Member_ID
),
rfm_score AS (
    SELECT r.*,
           NTILE(5) OVER (ORDER BY Recency_Days DESC) AS R,   -- recent = 5
           NTILE(5) OVER (ORDER BY Frequency)         AS F,
           NTILE(5) OVER (ORDER BY Monetary)          AS M
    FROM rfm_raw r
),
segmented AS (
    SELECT s.*,
           CASE
               WHEN R >= 4 AND F >= 4 AND M >= 4 THEN '1 Champions'
               WHEN R >= 3 AND F >= 3            THEN '2 Loyal'
               WHEN R >= 4 AND F <= 2            THEN '3 New / Promising'
               WHEN R <= 2 AND F >= 3            THEN '4 At Risk'
               WHEN R <= 2 AND F <= 2            THEN '5 Hibernating'
               ELSE                                   '6 Need Attention'
           END AS Segment
    FROM rfm_score s
)
SELECT Segment,
       COUNT(*)                               AS Customers,
       ROUND(AVG(Recency_Days))               AS Avg_Days_Since_Last_Order,
       ROUND(AVG(Frequency), 1)               AS Avg_Orders,
       ROUND(AVG(Monetary))                   AS Avg_Spend,
       ROUND(100 * SUM(Monetary) / SUM(SUM(Monetary)) OVER (), 1) AS Pct_Of_Revenue
FROM segmented
GROUP BY Segment
ORDER BY Segment;


-- ---------------------------------------------------------------------
-- Q7. Which regular customers have gone quiet? (churn early-warning list)
--     LAG() gives the previous order date per customer → typical gap between visits.
--     Flag customers whose current silence is > 3x their usual gap (min. 5 orders).
-- ---------------------------------------------------------------------
WITH visits AS (
    SELECT Member_ID,
           Order_DateTime,
           DATEDIFF(Order_DateTime,
                    LAG(Order_DateTime) OVER (PARTITION BY Member_ID ORDER BY Order_DateTime)) AS Gap_Days
    FROM Orders
    WHERE Order_Status <> 'Cancelled'
),
habits AS (
    SELECT Member_ID,
           COUNT(*)                         AS Orders,
           ROUND(AVG(Gap_Days), 1)          AS Usual_Gap_Days,
           MAX(Order_DateTime)              AS Last_Order_At,
           DATEDIFF(@as_of, MAX(Order_DateTime)) AS Days_Silent
    FROM visits
    GROUP BY Member_ID
    HAVING COUNT(*) >= 5
)
SELECT h.Member_ID, m.Member_Name, m.Member_Level, h.Orders, h.Usual_Gap_Days,
       DATE(h.Last_Order_At) AS Last_Order, h.Days_Silent,
       ROUND(h.Days_Silent / NULLIF(h.Usual_Gap_Days, 0), 1) AS Times_Longer_Than_Usual
FROM habits h
JOIN Member m ON m.Member_ID = h.Member_ID
WHERE h.Days_Silent > 3 * h.Usual_Gap_Days
  AND m.Member_Status = 'Active'
ORDER BY h.Orders DESC
LIMIT 50;


-- ---------------------------------------------------------------------
-- Q8. Do new customers come back? (cohort retention)
--     Cohort = month of a member's first order. For each cohort, what % ordered again
--     1, 2 and 3 months later. MIN() OVER (PARTITION BY member) finds the first month.
-- ---------------------------------------------------------------------
WITH member_months AS (
    SELECT DISTINCT Member_ID,
           DATE_FORMAT(Order_DateTime, '%Y-%m-01') AS Order_Month
    FROM Orders
    WHERE Order_Status <> 'Cancelled'
),
with_cohort AS (
    SELECT Member_ID, Order_Month,
           MIN(Order_Month) OVER (PARTITION BY Member_ID) AS Cohort_Month
    FROM member_months
),
offsets AS (
    SELECT Cohort_Month, Member_ID,
           TIMESTAMPDIFF(MONTH, Cohort_Month, Order_Month) AS Month_No
    FROM with_cohort
)
SELECT DATE_FORMAT(Cohort_Month, '%Y-%m')                                     AS Cohort,
       COUNT(DISTINCT CASE WHEN Month_No = 0 THEN Member_ID END)              AS New_Customers,
       ROUND(100 * COUNT(DISTINCT CASE WHEN Month_No = 1 THEN Member_ID END)
                 / COUNT(DISTINCT CASE WHEN Month_No = 0 THEN Member_ID END), 1) AS Retained_M1_Pct,
       ROUND(100 * COUNT(DISTINCT CASE WHEN Month_No = 2 THEN Member_ID END)
                 / COUNT(DISTINCT CASE WHEN Month_No = 0 THEN Member_ID END), 1) AS Retained_M2_Pct,
       ROUND(100 * COUNT(DISTINCT CASE WHEN Month_No = 3 THEN Member_ID END)
                 / COUNT(DISTINCT CASE WHEN Month_No = 0 THEN Member_ID END), 1) AS Retained_M3_Pct
FROM offsets
WHERE Cohort_Month >= '2025-06-01' AND Cohort_Month <= @as_of - INTERVAL 3 MONTH
GROUP BY Cohort_Month
ORDER BY Cohort_Month;


-- ---------------------------------------------------------------------
-- Q9. Did each promotion make customers spend more, and what did it cost?
--     Compares orders WITH the promotion vs orders WITHOUT it during the same dates.
--     Basket = Order_Amount before discount.
-- ---------------------------------------------------------------------
WITH promo_window AS (
    SELECT o.Order_ID, pr.Promotion_ID, pr.Promotion_Name, pr.Discount_Type,
           (o.Promotion_ID <=> pr.Promotion_ID) AS Used_Promo,   -- <=> is NULL-safe: no promo gives 0, not NULL
           o.Order_Amount,
           COALESCE(r.Discount, 0) AS Discount
    FROM Promotion pr
    JOIN Orders o  ON o.Order_DateTime >= pr.Start_Date
                  AND o.Order_DateTime <  pr.End_Date + INTERVAL 1 DAY
                  AND o.Order_Status <> 'Cancelled'
    LEFT JOIN Receipt r ON r.Order_ID = o.Order_ID
    WHERE pr.Start_Date >= '2025-01-01' AND pr.End_Date <= @as_of
)
SELECT Promotion_Name,
       Discount_Type,
       SUM(Used_Promo)                                                AS Promo_Orders,
       ROUND(AVG(CASE WHEN Used_Promo = 1 THEN Order_Amount END), 2)  AS Avg_Basket_With_Promo,
       ROUND(AVG(CASE WHEN Used_Promo = 0 THEN Order_Amount END), 2)  AS Avg_Basket_Without,
       ROUND(100 * (AVG(CASE WHEN Used_Promo = 1 THEN Order_Amount END)
                  / AVG(CASE WHEN Used_Promo = 0 THEN Order_Amount END) - 1), 1) AS Basket_Uplift_Pct,
       SUM(CASE WHEN Used_Promo = 1 THEN Discount ELSE 0 END)         AS Total_Discount_Given
FROM promo_window
GROUP BY Promotion_ID, Promotion_Name, Discount_Type
ORDER BY Promo_Orders DESC;


-- ---------------------------------------------------------------------
-- Q10. Which products are most often bought together? (for combo sets)
--      Self-join Order_Item to itself. The condition a.Product_ID < b.Product_ID avoids counting
--      each pair twice or pairing a product with itself.
-- ---------------------------------------------------------------------
SELECT pa.Product_Name AS Product_A,
       pb.Product_Name AS Product_B,
       COUNT(DISTINCT a.Order_ID) AS Orders_Together
FROM Order_Item a
JOIN Order_Item b ON b.Order_ID = a.Order_ID AND a.Product_ID < b.Product_ID
JOIN Product pa   ON pa.Product_ID = a.Product_ID
JOIN Product pb   ON pb.Product_ID = b.Product_ID
WHERE pa.Type_Product <> pb.Type_Product          -- drink + food style combos
GROUP BY pa.Product_Name, pb.Product_Name
ORDER BY Orders_Together DESC
LIMIT 15;


-- ---------------------------------------------------------------------
-- Q11. How long does delivery take at each branch? (median, not average)
--      MySQL has no MEDIAN(), so number rows in order (ROW_NUMBER) and pick the middle
--      one(s) using the group size from COUNT() OVER. Median ignores extreme outliers.
-- ---------------------------------------------------------------------
WITH times AS (
    SELECT o.Branch_ID,
           TIMESTAMPDIFF(MINUTE, o.Order_DateTime, d.Delivered_At) AS Minutes
    FROM Delivery d
    JOIN Orders o ON o.Order_ID = d.Order_ID
    WHERE d.Delivery_Status = 'Delivered'
),
ordered AS (
    SELECT Branch_ID, Minutes,
           ROW_NUMBER() OVER (PARTITION BY Branch_ID ORDER BY Minutes) AS rn,
           COUNT(*)     OVER (PARTITION BY Branch_ID)                  AS cnt
    FROM times
)
SELECT b.Branch_Name,
       MAX(o.cnt)                    AS Deliveries,
       ROUND(AVG(o.Minutes), 1)      AS Median_Minutes,
       (SELECT ROUND(AVG(Minutes), 1) FROM times t WHERE t.Branch_ID = o.Branch_ID) AS Mean_Minutes
FROM ordered o
JOIN Branch b ON b.Branch_ID = o.Branch_ID
WHERE o.rn IN (FLOOR((o.cnt + 1) / 2), CEIL((o.cnt + 1) / 2))
GROUP BY o.Branch_ID, b.Branch_Name
ORDER BY Median_Minutes DESC, Deliveries DESC;


-- ---------------------------------------------------------------------
-- Q12. Which branches had unusually quiet days in September 2026 (fewer than 3 orders)?
--      A RECURSIVE CTE builds a calendar (one row per day), CROSS JOIN with branches
--      gives every branch-day, and LEFT JOIN keeps days with zero orders too.
--      Orders are summarised ONCE first (one index range scan) instead of being
--      checked separately for each of the 1,500 branch-days. See Phase 4.
-- ---------------------------------------------------------------------
WITH RECURSIVE calendar AS (
    SELECT DATE('2026-09-01') AS Day
    UNION ALL
    SELECT Day + INTERVAL 1 DAY FROM calendar WHERE Day < '2026-09-30'
),
daily AS (
    SELECT Branch_ID, DATE(Order_DateTime) AS Day, COUNT(*) AS Orders
    FROM Orders
    WHERE Order_DateTime >= '2026-09-01' AND Order_DateTime < '2026-10-01'
    GROUP BY Branch_ID, DATE(Order_DateTime)
)
SELECT b.Branch_Name,
       b.Branch_Status,
       COUNT(*)                                                AS Quiet_Days,
       SUM(COALESCE(d.Orders, 0) = 0)                          AS Zero_Order_Days,
       GROUP_CONCAT(DAY(c.Day) ORDER BY c.Day SEPARATOR ', ')  AS Days_Of_Month
FROM calendar c
CROSS JOIN Branch b
LEFT JOIN daily d ON d.Branch_ID = b.Branch_ID AND d.Day = c.Day
WHERE COALESCE(d.Orders, 0) < 3
GROUP BY b.Branch_ID, b.Branch_Name, b.Branch_Status
ORDER BY Quiet_Days DESC;
