-- =====================================================================
-- Phase 3 — 01 Views
-- Run after schema + seed. Views hide join logic so reports and
-- analysts can query one "virtual table" instead of 5 joined tables.
--
-- Definitions used everywhere in this project:
--   Gross sales   = Orders.Order_Amount (sum of item lines)
--   Net sales     = Gross sales - Receipt.Discount
--   Paid amount   = Payment.Amount (net sales + delivery fee), Payment_Status = 'Success'
-- =====================================================================
USE coffee_chain_db;
SET NAMES utf8mb4;   -- make sure accented names (Caffè, Açaí) are stored correctly

-- ---------------------------------------------------------------------
-- v_order_summary: one row per order with everything a report needs
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_order_summary AS
SELECT
    o.Order_ID,
    o.Order_DateTime,
    DATE(o.Order_DateTime)                      AS Order_Date,
    o.Order_Type,
    o.Order_Status,
    o.Member_ID,
    m.Member_Name,
    m.Member_Level,
    o.Branch_ID,
    b.Branch_Name,
    b.Store_Type,
    o.Promotion_ID,
    pr.Promotion_Name,
    o.Order_Amount                              AS Gross_Amount,
    COALESCE(r.Discount, 0)                     AS Discount,
    o.Order_Amount - COALESCE(r.Discount, 0)    AS Net_Amount,
    COALESCE(d.Delivery_Fee, 0)                 AS Delivery_Fee,
    p.Payment_Method,
    p.Amount                                    AS Paid_Amount
FROM Orders o
JOIN Member m          ON m.Member_ID = o.Member_ID
JOIN Branch b          ON b.Branch_ID = o.Branch_ID
LEFT JOIN Promotion pr ON pr.Promotion_ID = o.Promotion_ID
LEFT JOIN Receipt r    ON r.Order_ID = o.Order_ID
LEFT JOIN Delivery d   ON d.Order_ID = o.Order_ID
LEFT JOIN Payment p    ON p.Order_ID = o.Order_ID AND p.Payment_Status = 'Success';

-- ---------------------------------------------------------------------
-- v_daily_branch_sales: daily KPIs per branch (cancelled orders excluded)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_daily_branch_sales AS
SELECT
    DATE(o.Order_DateTime)                       AS Sales_Date,
    o.Branch_ID,
    b.Branch_Name,
    COUNT(*)                                     AS Orders,
    SUM(o.Order_Amount)                          AS Gross_Sales,
    SUM(COALESCE(r.Discount, 0))                 AS Discounts,
    SUM(o.Order_Amount - COALESCE(r.Discount,0)) AS Net_Sales,
    ROUND(AVG(o.Order_Amount), 2)                AS Avg_Order_Value
FROM Orders o
JOIN Branch b       ON b.Branch_ID = o.Branch_ID
LEFT JOIN Receipt r ON r.Order_ID = o.Order_ID
WHERE o.Order_Status <> 'Cancelled'
GROUP BY DATE(o.Order_DateTime), o.Branch_ID, b.Branch_Name;

-- ---------------------------------------------------------------------
-- v_member_summary: customer profile with lifetime value
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_member_summary AS
SELECT
    m.Member_ID,
    m.Member_Name,
    m.Member_Level,
    m.Member_Status,
    m.Registration_Date,
    m.Points,
    COUNT(o.Order_ID)                    AS Total_Orders,
    COALESCE(SUM(p.Amount), 0)           AS Lifetime_Spend,
    ROUND(AVG(p.Amount), 2)              AS Avg_Paid_Per_Order,
    MIN(o.Order_DateTime)                AS First_Order_At,
    MAX(o.Order_DateTime)                AS Last_Order_At
FROM Member m
LEFT JOIN Orders o  ON o.Member_ID = m.Member_ID AND o.Order_Status <> 'Cancelled'
LEFT JOIN Payment p ON p.Order_ID = o.Order_ID AND p.Payment_Status = 'Success'
GROUP BY m.Member_ID, m.Member_Name, m.Member_Level, m.Member_Status, m.Registration_Date, m.Points;

-- ---------------------------------------------------------------------
-- v_product_sales: units and revenue per product (cancelled orders excluded)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_product_sales AS
SELECT
    p.Product_ID,
    p.Product_Name,
    p.Type_Product,
    p.Base_Price,
    COALESCE(SUM(i.Quantity), 0)         AS Units_Sold,
    COALESCE(SUM(i.Line_Total), 0)       AS Gross_Revenue,
    COUNT(DISTINCT i.Order_ID)           AS Orders_Containing
FROM Product p
LEFT JOIN Order_Item i ON i.Product_ID = p.Product_ID
LEFT JOIN Orders o     ON o.Order_ID = i.Order_ID
WHERE o.Order_ID IS NULL OR o.Order_Status <> 'Cancelled'
GROUP BY p.Product_ID, p.Product_Name, p.Type_Product, p.Base_Price;

-- quick test
-- SELECT * FROM v_order_summary ORDER BY Order_ID DESC LIMIT 10;
-- SELECT * FROM v_daily_branch_sales WHERE Sales_Date = '2026-09-30' ORDER BY Net_Sales DESC;
-- SELECT * FROM v_member_summary ORDER BY Lifetime_Spend DESC LIMIT 10;
-- SELECT * FROM v_product_sales ORDER BY Units_Sold DESC;
