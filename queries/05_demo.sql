-- =====================================================================
-- Phase 3 — 05 Demo: watch the triggers and procedures work
-- Run after 01-04. Safe to run more than once (each run adds new demo orders).
--
-- Each "try" prints a row: ALLOWED, or BLOCKED + the reason, so the whole
-- script runs to the end even when a rule (correctly) rejects something.
-- =====================================================================
USE coffee_chain_db;
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_demo_try;
DELIMITER $$
CREATE PROCEDURE sp_demo_try(IN p_test VARCHAR(200), IN p_sql TEXT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @demo_msg = MESSAGE_TEXT;
        SELECT p_test AS Test, 'BLOCKED' AS Result, @demo_msg AS Reason;
    END;
    SET @demo_sql = p_sql;
    PREPARE demo_stmt FROM @demo_sql;
    EXECUTE demo_stmt;
    DEALLOCATE PREPARE demo_stmt;
    SELECT p_test AS Test, 'ALLOWED' AS Result, NULL AS Reason;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- 1. Before: member 100011, card and points
-- ---------------------------------------------------------------------
SELECT m.Member_ID, m.Member_Name, m.Points, m.Member_Level, c.Card_ID, c.Balance AS Card_Balance
FROM Member m LEFT JOIN Starbucks_Card c ON c.Member_ID = m.Member_ID AND c.Card_Status = 'Active'
WHERE m.Member_ID = 100011;

-- ---------------------------------------------------------------------
-- 2. Place a pickup order paid by Starbucks Card
--    (prices are filled in by trigger, card is charged, points are added)
-- ---------------------------------------------------------------------
SET @card := (SELECT Card_ID FROM Starbucks_Card WHERE Member_ID = 100011 AND Card_Status = 'Active' LIMIT 1);

CALL sp_place_order(
    100011, 1001, 'InStorePickup',
    '[{"product_id":200002,"qty":2,"size":"Grande","customize":"Oat milk"},
      {"product_id":200029,"qty":1}]',
    NULL, 'StarbucksCard', @card, NULL, '2026-10-01 08:30:00', @order1);

SELECT m.Member_ID, m.Points, m.Member_Level, c.Balance AS Card_Balance_After
FROM Member m JOIN Starbucks_Card c ON c.Card_ID = @card
WHERE m.Member_ID = 100011;

SELECT * FROM Order_Item WHERE Order_ID = @order1;

-- ---------------------------------------------------------------------
-- 3. Delivery order using an active promotion (15% off), paid by QR
-- ---------------------------------------------------------------------
CALL sp_place_order(
    100012, 1004, 'Delivery',
    '[{"product_id":200003,"qty":2,"size":"Venti"},
      {"product_id":200036,"qty":1}]',
    300006, 'QR', NULL, NULL, '2026-10-01 12:15:00', @order2);

-- ---------------------------------------------------------------------
-- 4. Rules that should BLOCK bad input
-- ---------------------------------------------------------------------
CALL sp_demo_try('Order a discontinued product (Pumpkin Spice Latte)',
  'CALL sp_place_order(100011, 1001, ''InStorePickup'', ''[{"product_id":200010,"qty":1}]'', NULL, ''Cash'', NULL, NULL, ''2026-10-01 09:00:00'', @x)');

CALL sp_demo_try('Order-to-Table at a Drive Thru',
  'CALL sp_place_order(100011, 1003, ''OrderToTable'', ''[{"product_id":200001,"qty":1}]'', NULL, ''Cash'', NULL, 5, ''2026-10-01 09:00:00'', @x)');

CALL sp_demo_try('Order at 05:00 before the branch opens',
  'CALL sp_place_order(100011, 1001, ''InStorePickup'', ''[{"product_id":200001,"qty":1}]'', NULL, ''Cash'', NULL, NULL, ''2026-10-01 05:00:00'', @x)');

CALL sp_demo_try('Use a promotion that already ended',
  'CALL sp_place_order(100011, 1001, ''InStorePickup'', ''[{"product_id":200001,"qty":1}]'', 300001, ''Cash'', NULL, NULL, ''2026-10-01 09:00:00'', @x)');

CALL sp_demo_try('Pay for a delivery in cash',
  'CALL sp_place_order(100011, 1001, ''Delivery'', ''[{"product_id":200001,"qty":1}]'', NULL, ''Cash'', NULL, NULL, ''2026-10-01 09:00:00'', @x)');

CALL sp_demo_try('Pay with another member''s Starbucks Card',
  CONCAT('CALL sp_place_order(100012, 1001, ''InStorePickup'', ''[{"product_id":200001,"qty":1}]'', NULL, ''StarbucksCard'', ', @card, ', NULL, ''2026-10-01 09:00:00'', @x)'));

CALL sp_demo_try('Card balance too low (10 mugs)',
  CONCAT('CALL sp_place_order(100011, 1001, ''InStorePickup'', ''[{"product_id":200009,"qty":10}]'', NULL, ''StarbucksCard'', ', @card, ', NULL, ''2026-10-01 09:00:00'', @x)'));

CALL sp_demo_try('Banned member places an order',
  CONCAT('CALL sp_place_order(', (SELECT MIN(Member_ID) FROM Member WHERE Member_Status = 'Banned'),
         ', 1001, ''InStorePickup'', ''[{"product_id":200001,"qty":1}]'', NULL, ''Cash'', NULL, NULL, ''2026-10-01 09:00:00'', @x)'));

CALL sp_demo_try('Redeem more points than the member has',
  'CALL sp_redeem_points(100012, 999999)');

CALL sp_demo_try('Re-open a Completed order',
  'UPDATE Orders SET Order_Status = ''Pending'' WHERE Order_ID = 400011');

CALL sp_demo_try('Cancel a Completed order',
  'CALL sp_cancel_order(400011)');

-- proof that a blocked order left nothing behind (transaction was rolled back)
SELECT COUNT(*) AS Orders_At_0500_Should_Be_0
FROM Orders WHERE Order_DateTime = '2026-10-01 05:00:00';

-- ---------------------------------------------------------------------
-- 5. Redeem points (allowed)
-- ---------------------------------------------------------------------
CALL sp_redeem_points(100012, 200);

-- ---------------------------------------------------------------------
-- 6. Cancel order 1: card money comes back, earned points are taken back
-- ---------------------------------------------------------------------
CALL sp_cancel_order(@order1);

SELECT m.Member_ID, m.Points, c.Balance AS Card_Balance_After_Refund
FROM Member m JOIN Starbucks_Card c ON c.Card_ID = @card
WHERE m.Member_ID = 100011;

SELECT Txn_ID, Order_ID, Txn_Type, Points_Change, Created_At
FROM Point_Transaction WHERE Order_ID = @order1 ORDER BY Txn_ID;

-- ---------------------------------------------------------------------
-- 7. Branch manager report (3 result sets)
-- ---------------------------------------------------------------------
CALL sp_branch_report(1001, '2026-09-01', '2026-09-30');

DROP PROCEDURE IF EXISTS sp_demo_try;
