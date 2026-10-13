-- =====================================================================
-- Phase 4 — 02 Create indexes
-- Each index is designed for specific queries in 01_benchmark_queries.sql
-- and 02_analytics.sql. Rules used:
--   * Equality columns first, range column (dates) last:
--       WHERE Branch_ID = ? AND Order_DateTime BETWEEN ...  ->  (Branch_ID, Order_DateTime)
--   * Put the ORDER BY column right after the equality column to skip sorting:
--       WHERE Member_ID = ? ORDER BY Order_DateTime         ->  (Member_ID, Order_DateTime)
--   * "Covering" index = includes every column the query needs, so MySQL
--     never reads the table itself.
--   * Don't keep redundant indexes: (Branch_ID, Order_DateTime) already starts
--     with Branch_ID, so the old single-column index can go. Every index costs
--     disk space and slows down INSERT/UPDATE.
-- Run 03_drop_indexes.sql first if you have run this file before.
-- =====================================================================
USE coffee_chain_db;

-- B1, B8, analytics Q2/Q3/Q4/Q5: anything filtered by a date range
CREATE INDEX idx_orders_datetime
    ON Orders (Order_DateTime);

-- B3, sp_branch_report: one branch + date range
CREATE INDEX idx_orders_branch_datetime
    ON Orders (Branch_ID, Order_DateTime);

-- B4, analytics Q7: a member's orders in date order (no filesort)
CREATE INDEX idx_orders_member_datetime
    ON Orders (Member_ID, Order_DateTime);

-- B5, analytics Q1: covering index for revenue by period.
-- Paid_At goes FIRST even though Payment_Status is the equality column:
-- 99.99% of payments are 'Success', so an index starting with Payment_Status
-- barely narrows anything down, and in testing it tricked the optimizer into
-- a slower plan for analytics Q3/Q6 (190k random lookups). Low-variety columns
-- should not lead an index.
CREATE INDEX idx_payment_paidat
    ON Payment (Paid_At, Payment_Status, Amount);

-- B8, analytics Q10 (products bought together): covering index for joining
-- items by order and reading which product/how many, without touching the table
CREATE INDEX idx_order_item_order_product
    ON Order_Item (Order_ID, Product_ID, Quantity);

-- B6: name search (prefix)
CREATE INDEX idx_member_name
    ON Member (Member_Name);

-- Redundant indexes: the new composite indexes start with Branch_ID / Member_ID /
-- Order_ID, so they can also serve those foreign keys.
-- On a fresh database MySQL has ALREADY dropped the old single-column FK indexes
-- automatically (implicit FK indexes are removed once a better index exists).
-- If they were re-created by hand (03_drop_indexes.sql), drop them here.
SET @s = (SELECT IF(COUNT(*) > 0, 'ALTER TABLE Orders DROP INDEX FK_Orders_Branch', 'DO 0')
          FROM information_schema.STATISTICS
          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'Orders' AND INDEX_NAME = 'FK_Orders_Branch');
PREPARE stmt FROM @s; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @s = (SELECT IF(COUNT(*) > 0, 'ALTER TABLE Orders DROP INDEX FK_Orders_Member', 'DO 0')
          FROM information_schema.STATISTICS
          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'Orders' AND INDEX_NAME = 'FK_Orders_Member');
PREPARE stmt FROM @s; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @s = (SELECT IF(COUNT(*) > 0, 'ALTER TABLE Order_Item DROP INDEX FK_Order_Item_Order', 'DO 0')
          FROM information_schema.STATISTICS
          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'Order_Item' AND INDEX_NAME = 'FK_Order_Item_Order');
PREPARE stmt FROM @s; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- refresh statistics so the optimizer knows about the new indexes
ANALYZE TABLE Orders, Order_Item, Payment, Member;

-- what we have now
SELECT TABLE_NAME, INDEX_NAME, GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS Columns
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'coffee_chain_db' AND TABLE_NAME IN ('Orders', 'Order_Item', 'Payment', 'Member')
GROUP BY TABLE_NAME, INDEX_NAME
ORDER BY TABLE_NAME, INDEX_NAME;
