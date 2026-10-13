-- =====================================================================
-- Phase 3 — 03 Triggers (business rules enforced inside the database)
-- Run AFTER the seed data (seed_small + seed_large), because these triggers
-- would otherwise award points/charge cards a second time while seeding.
--
-- Already in schema_v2.sql:
--   trg_order_item_ai/au/ad   keep Orders.Order_Amount = SUM(Order_Item.Line_Total)
--
-- Added here:
--   trg_order_item_bi   block unavailable products, block editing closed orders,
--                       fill Unit_Price automatically from Base_Price + size
--   trg_orders_bu       order status can only move forward (Cancelled/Completed are final)
--   trg_payment_bi      Starbucks Card checks: owner, active, enough balance
--   trg_payment_ai      after a successful payment: charge the card, award points,
--                       mark the order Paid
--   trg_payment_au      on refund: give money back to the card, take earned points back
--   trg_point_txn_ai    keep Member.Points in sync and upgrade to Gold at 500 points
-- =====================================================================
USE coffee_chain_db;
SET NAMES utf8mb4;

DROP TRIGGER IF EXISTS trg_order_item_bi;
DROP TRIGGER IF EXISTS trg_orders_bu;
DROP TRIGGER IF EXISTS trg_payment_bi;
DROP TRIGGER IF EXISTS trg_payment_ai;
DROP TRIGGER IF EXISTS trg_payment_au;
DROP TRIGGER IF EXISTS trg_point_txn_ai;

DELIMITER $$

-- ---------------------------------------------------------------------
-- Order_Item BEFORE INSERT
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_order_item_bi
BEFORE INSERT ON Order_Item
FOR EACH ROW
BEGIN
    DECLARE v_active   TINYINT;
    DECLARE v_price    DECIMAL(8,2);
    DECLARE v_type     VARCHAR(30);
    DECLARE v_name     VARCHAR(100);
    DECLARE v_status   VARCHAR(20);

    SELECT Is_Active, Base_Price, Type_Product, Product_Name
      INTO v_active, v_price, v_type, v_name
    FROM Product WHERE Product_ID = NEW.Product_ID;

    IF v_active = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'This product is no longer available (Is_Active = 0)';
    END IF;

    SELECT Order_Status INTO v_status FROM Orders WHERE Order_ID = NEW.Order_ID;
    IF v_status <> 'Pending' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Items can only be added while the order is Pending';
    END IF;

    -- only drinks have sizes
    IF v_type <> 'Beverage' THEN
        SET NEW.Size = NULL;
    ELSEIF NEW.Size IS NULL THEN
        SET NEW.Size = 'Tall';
    END IF;

    -- price comes from the menu unless given explicitly
    IF NEW.Unit_Price IS NULL THEN
        SET NEW.Unit_Price = v_price + CASE NEW.Size WHEN 'Short'  THEN -10
                                                     WHEN 'Grande' THEN  15
                                                     WHEN 'Venti'  THEN  30
                                                     ELSE 0 END;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- Orders BEFORE UPDATE: status can only move forward
--   Pending -> Paid -> Completed,  Pending/Paid -> Cancelled
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_orders_bu
BEFORE UPDATE ON Orders
FOR EACH ROW
BEGIN
    IF NEW.Order_Status <> OLD.Order_Status THEN
        IF OLD.Order_Status IN ('Cancelled', 'Completed') THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Cancelled or Completed orders cannot change status';
        END IF;
        IF OLD.Order_Status = 'Paid' AND NEW.Order_Status = 'Pending' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'A paid order cannot go back to Pending';
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- Payment BEFORE INSERT: validate Starbucks Card payments
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_payment_bi
BEFORE INSERT ON Payment
FOR EACH ROW
BEGIN
    DECLARE v_order_member INT;
    DECLARE v_order_status VARCHAR(20);
    DECLARE v_card_member  INT;
    DECLARE v_card_status  VARCHAR(20);
    DECLARE v_balance      DECIMAL(10,2);

    SELECT Member_ID, Order_Status INTO v_order_member, v_order_status
    FROM Orders WHERE Order_ID = NEW.Order_ID;

    IF v_order_status = 'Cancelled' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot pay for a cancelled order';
    END IF;

    IF NEW.Payment_Method = 'StarbucksCard' THEN
        SELECT Member_ID, Card_Status, Balance
          INTO v_card_member, v_card_status, v_balance
        FROM Starbucks_Card WHERE Card_ID = NEW.Card_ID;

        IF v_card_member <> v_order_member THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This Starbucks Card belongs to another member';
        END IF;
        IF v_card_status <> 'Active' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This Starbucks Card is not active';
        END IF;
        IF NEW.Payment_Status = 'Success' AND v_balance < NEW.Amount THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Not enough balance on the Starbucks Card';
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- Payment AFTER INSERT: charge card, award points, mark order Paid
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_payment_ai
AFTER INSERT ON Payment
FOR EACH ROW
BEGIN
    DECLARE v_member     INT;
    DECLARE v_multiplier DECIMAL(8,2) DEFAULT 1;
    DECLARE v_points     INT;

    IF NEW.Payment_Status = 'Success' THEN
        IF NEW.Payment_Method = 'StarbucksCard' THEN
            UPDATE Starbucks_Card SET Balance = Balance - NEW.Amount WHERE Card_ID = NEW.Card_ID;
        END IF;

        SELECT o.Member_ID,
               IF(p.Discount_Type = 'Point_Multiplier', p.Discount_Value, 1)
          INTO v_member, v_multiplier
        FROM Orders o
        LEFT JOIN Promotion p ON p.Promotion_ID = o.Promotion_ID
        WHERE o.Order_ID = NEW.Order_ID;

        SET v_points = FLOOR(NEW.Amount / 10) * v_multiplier;
        IF v_points > 0 THEN
            INSERT INTO Point_Transaction (Member_ID, Order_ID, Txn_Type, Points_Change, Created_At)
            VALUES (v_member, NEW.Order_ID, 'Earn', v_points, NEW.Paid_At);
        END IF;

        UPDATE Orders SET Order_Status = 'Paid'
        WHERE Order_ID = NEW.Order_ID AND Order_Status = 'Pending';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- Payment AFTER UPDATE: refund handling
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_payment_au
AFTER UPDATE ON Payment
FOR EACH ROW
BEGIN
    DECLARE v_member  INT;
    DECLARE v_earned  INT;
    DECLARE v_balance INT;
    DECLARE v_takeback INT;

    IF OLD.Payment_Status = 'Success' AND NEW.Payment_Status = 'Refunded' THEN
        IF NEW.Payment_Method = 'StarbucksCard' THEN
            UPDATE Starbucks_Card SET Balance = Balance + NEW.Amount WHERE Card_ID = NEW.Card_ID;
        END IF;

        SELECT Member_ID INTO v_member FROM Orders WHERE Order_ID = NEW.Order_ID;
        SELECT COALESCE(SUM(Points_Change), 0) INTO v_earned
        FROM Point_Transaction WHERE Order_ID = NEW.Order_ID AND Txn_Type = 'Earn';
        SELECT Points INTO v_balance FROM Member WHERE Member_ID = v_member;

        -- never take back more than the member currently has
        SET v_takeback = LEAST(v_earned, v_balance);
        IF v_takeback > 0 THEN
            INSERT INTO Point_Transaction (Member_ID, Order_ID, Txn_Type, Points_Change)
            VALUES (v_member, NEW.Order_ID, 'Adjust', -v_takeback);
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- Point_Transaction AFTER INSERT: keep Member.Points in sync
--   (MySQL evaluates SET assignments left to right, so Member_Level
--    sees the already-updated Points value)
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_point_txn_ai
AFTER INSERT ON Point_Transaction
FOR EACH ROW
BEGIN
    UPDATE Member
    SET Points       = Points + NEW.Points_Change,
        Member_Level = IF(Points >= 500, 'Gold', Member_Level)
    WHERE Member_ID = NEW.Member_ID;
END$$

DELIMITER ;
