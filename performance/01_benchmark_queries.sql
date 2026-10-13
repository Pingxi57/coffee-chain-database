-- =====================================================================
-- Phase 4 — 01 Benchmark queries
-- Run this file TWICE:
--   1) before indexes  (fresh database, or after 03_drop_indexes.sql)
--   2) after  02_create_indexes.sql
-- and compare the EXPLAIN ANALYZE output of each query.
--
-- How to read EXPLAIN ANALYZE (one tree per query):
--   "Table scan on Orders"           -> reads EVERY row (slow on big tables)
--   "Index lookup / Index range scan" -> jumps straight to the matching rows
--   "Covering index ..."              -> answers from the index alone, never touches the table
--   "Sort" / "filesort"               -> extra sorting step the index could have avoided
--   (actual time=A..B rows=R loops=L) -> B = milliseconds until the last row, R = rows produced
--
-- Each query is a realistic request from the app or from a manager's report.
-- =====================================================================
USE coffee_chain_db;
SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- B1. Today's sales (dashboard tile): all orders on one day
-- ---------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT COUNT(*) AS Orders, SUM(Order_Amount) AS Gross_Sales
FROM Orders
WHERE Order_DateTime >= '2026-09-30'
  AND Order_DateTime <  '2026-10-01';

-- ---------------------------------------------------------------------
-- B2. Same question written with DATE() around the column
--     Wrapping an indexed column in a function hides it from the index
--     ("non-sargable"), so this stays slow even after indexing.
-- ---------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT COUNT(*) AS Orders, SUM(Order_Amount) AS Gross_Sales
FROM Orders
WHERE DATE(Order_DateTime) = '2026-09-30';

-- ---------------------------------------------------------------------
-- B3. Branch manager's monthly report: one branch, one month, by day
-- ---------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT DATE(Order_DateTime) AS Day, COUNT(*) AS Orders, SUM(Order_Amount) AS Gross_Sales
FROM Orders
WHERE Branch_ID = 1001
  AND Order_DateTime >= '2026-09-01'
  AND Order_DateTime <  '2026-10-01'
GROUP BY DATE(Order_DateTime);

-- ---------------------------------------------------------------------
-- B4. App screen "My recent orders": a member's last 10 orders
-- ---------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT Order_ID, Order_DateTime, Order_Type, Order_Amount
FROM Orders
WHERE Member_ID = 100011
ORDER BY Order_DateTime DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- B5. Finance: daily revenue for last month (successful payments only)
-- ---------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT DATE(Paid_At) AS Day, COUNT(*) AS Payments, SUM(Amount) AS Revenue
FROM Payment
WHERE Payment_Status = 'Success'
  AND Paid_At >= '2026-09-01'
  AND Paid_At <  '2026-10-01'
GROUP BY DATE(Paid_At);

-- ---------------------------------------------------------------------
-- B6. Staff searches a customer by name (starts with ...)
-- ---------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT Member_ID, Member_Name, Phone_Number
FROM Member
WHERE Member_Name LIKE 'Krit Th%';

-- ---------------------------------------------------------------------
-- B7. Same search but "contains ..." (leading wildcard)
--     A B-tree index is sorted by the beginning of the text, so '%...'
--     cannot use it. This stays a full scan by design.
-- ---------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT Member_ID, Member_Name, Phone_Number
FROM Member
WHERE Member_Name LIKE '%Thongdee';

-- ---------------------------------------------------------------------
-- B8. Best sellers of the last 7 days (dashboard): join Orders -> Order_Item -> Product
-- ---------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT p.Product_Name, SUM(i.Quantity) AS Units
FROM Orders o
JOIN Order_Item i ON i.Order_ID = o.Order_ID
JOIN Product p    ON p.Product_ID = i.Product_ID
WHERE o.Order_DateTime >= '2026-09-24'
  AND o.Order_DateTime <  '2026-10-01'
  AND o.Order_Status <> 'Cancelled'
GROUP BY p.Product_ID, p.Product_Name
ORDER BY Units DESC
LIMIT 10;
