-- =====================================================================
-- Phase 3 — 04 Stored function and procedures
-- Run after 03_triggers.sql (the procedures rely on those triggers).
--
--   fn_calc_discount(promotion, amount)   discount in THB for an order amount
--   sp_place_order(...)                   create a complete order in ONE transaction
--   sp_cancel_order(order_id)             cancel + refund (card money and points)
--   sp_redeem_points(member, points)      spend points with clear error messages
--   sp_branch_report(branch, from, to)    3 result sets for a branch manager
-- =====================================================================
USE coffee_chain_db;
SET NAMES utf8mb4;

DROP FUNCTION  IF EXISTS fn_calc_discount;
DROP PROCEDURE IF EXISTS sp_place_order;
DROP PROCEDURE IF EXISTS sp_cancel_order;
DROP PROCEDURE IF EXISTS sp_redeem_points;
DROP PROCEDURE IF EXISTS sp_branch_report;

DELIMITER $$

-- ---------------------------------------------------------------------
-- fn_calc_discount: same rule as the receipts in the seed data
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_calc_discount(p_promotion_id INT, p_amount DECIMAL(10,2))
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_type  VARCHAR(20);
    DECLARE v_value DECIMAL(8,2);

    IF p_promotion_id IS NULL THEN
        RETURN 0;
    END IF;

    SELECT Discount_Type, Discount_Value INTO v_type, v_value
    FROM Promotion WHERE Promotion_ID = p_promotion_id;

    RETURN CASE v_type
               WHEN 'Baht'    THEN LEAST(v_value, p_amount)
               WHEN 'Percent' THEN ROUND(p_amount * v_value / 100, 2)
               ELSE 0          -- Point_Multiplier gives points, not money
           END;
END$$

-- ---------------------------------------------------------------------
-- sp_place_order
--   p_items example:
--     '[{"product_id":200002,"qty":2,"size":"Grande","customize":"Oat milk"},
--       {"product_id":200029,"qty":1}]'
--   p_order_time: NULL = now
--   p_table_number: only for OrderToTable
--   Everything (order, items, subtype, receipt, payment, points) succeeds
--   together or is rolled back together.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_place_order(
    IN  p_member_id      INT,
    IN  p_branch_id      INT,
    IN  p_order_type     VARCHAR(20),
    IN  p_items          JSON,
    IN  p_promotion_id   INT,
    IN  p_payment_method VARCHAR(20),
    IN  p_card_id        INT,
    IN  p_table_number   INT,
    IN  p_order_time     DATETIME,
    OUT p_order_id       INT
)
BEGIN
    DECLARE v_time          DATETIME DEFAULT COALESCE(p_order_time, NOW());
    DECLARE v_member_status VARCHAR(20);
    DECLARE v_branch_status VARCHAR(20);
    DECLARE v_store_type    VARCHAR(30);
    DECLARE v_open          TIME;
    DECLARE v_close         TIME;
    DECLARE v_amount        DECIMAL(10,2);
    DECLARE v_discount      DECIMAL(10,2);
    DECLARE v_fee           DECIMAL(8,2) DEFAULT 0;
    DECLARE v_address       VARCHAR(255);
    DECLARE v_phone         VARCHAR(15);

    -- any error: undo everything, then pass the error on to the caller
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- ---- validation ---------------------------------------------------
    SELECT Member_Status INTO v_member_status FROM Member WHERE Member_ID = p_member_id;
    IF v_member_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Member not found';
    ELSEIF v_member_status <> 'Active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Member account is not active';
    END IF;

    SELECT Branch_Status, Store_Type, Open_Time, Close_Time
      INTO v_branch_status, v_store_type, v_open, v_close
    FROM Branch WHERE Branch_ID = p_branch_id;
    IF v_branch_status IS NULL OR v_branch_status <> 'Open' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Branch is not open for orders';
    END IF;
    IF TIME(v_time) < v_open OR TIME(v_time) > v_close THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order time is outside the branch opening hours';
    END IF;

    IF p_order_type = 'OrderToTable' AND v_store_type = 'Drive Thru' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Drive Thru branches have no tables';
    END IF;
    IF p_order_type = 'OrderToTable' AND (p_table_number IS NULL OR p_table_number < 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Table number is required for Order-to-Table';
    END IF;
    IF p_order_type = 'Delivery' AND p_payment_method = 'Cash' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Delivery orders cannot be paid in cash';
    END IF;

    IF p_items IS NULL OR JSON_LENGTH(p_items) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'An order needs at least one item';
    END IF;

    IF p_promotion_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM Promotion
        WHERE Promotion_ID = p_promotion_id
          AND DATE(v_time) BETWEEN Start_Date AND End_Date
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Promotion is not valid on the order date';
    END IF;

    IF p_order_type = 'Delivery' THEN
        SELECT CONCAT(a.Address_Line, ', ', COALESCE(a.District, ''), ', ', a.Province, ' ', COALESCE(a.Postal_Code, '')),
               m.Phone_Number
          INTO v_address, v_phone
        FROM Member m
        JOIN Member_Address a ON a.Member_ID = m.Member_ID AND a.Is_Default = 1
        WHERE m.Member_ID = p_member_id
        LIMIT 1;
        IF v_address IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Member has no default delivery address';
        END IF;
    END IF;

    -- ---- write everything in one transaction ---------------------------
    START TRANSACTION;

    INSERT INTO Orders (Member_ID, Branch_ID, Promotion_ID, Order_Type, Order_Status, Order_DateTime)
    VALUES (p_member_id, p_branch_id, p_promotion_id, p_order_type, 'Pending', v_time);
    SET p_order_id = LAST_INSERT_ID();

    -- JSON_TABLE turns the JSON array into rows. Unit_Price is left NULL so
    -- trg_order_item_bi fills it from the menu, and the amount triggers update the total.
    INSERT INTO Order_Item (Order_ID, Product_ID, Size, Customize, Quantity, Unit_Price)
    SELECT p_order_id, j.product_id, j.size, j.customize, j.qty, NULL
    FROM JSON_TABLE(p_items, '$[*]' COLUMNS (
            product_id INT          PATH '$.product_id',
            qty        INT          PATH '$.qty' DEFAULT '1' ON EMPTY,
            size       VARCHAR(10)  PATH '$.size',
            customize  VARCHAR(200) PATH '$.customize'
         )) AS j;

    IF p_order_type = 'InStorePickup' THEN
        INSERT INTO InStorePickup (Order_ID, Pickup_Time, Pickup_Status) VALUES (p_order_id, NULL, 'Waiting');
    ELSEIF p_order_type = 'OrderToTable' THEN
        INSERT INTO OrderToTable (Order_ID, Table_Number) VALUES (p_order_id, p_table_number);
    END IF;

    SELECT Order_Amount INTO v_amount FROM Orders WHERE Order_ID = p_order_id;
    SET v_discount = fn_calc_discount(p_promotion_id, v_amount);

    IF p_order_type = 'Delivery' THEN
        SET v_fee = IF(v_amount >= 500, 0, 30);
        INSERT INTO Delivery (Order_ID, Delivery_Address, Contact_Phone, Delivery_Fee, Delivery_Status)
        VALUES (p_order_id, v_address, v_phone, v_fee, 'Preparing');
    END IF;

    INSERT INTO Receipt (Order_ID, Receipt_DateTime, Discount)
    VALUES (p_order_id, v_time, v_discount);

    -- payment triggers: check/charge the card, award points, set status to Paid
    INSERT INTO Payment (Order_ID, Payment_Method, Card_ID, Amount, Paid_At, Payment_Status)
    VALUES (p_order_id, p_payment_method,
            IF(p_payment_method = 'StarbucksCard', p_card_id, NULL),
            v_amount - v_discount + v_fee, v_time, 'Success');

    COMMIT;

    SELECT * FROM v_order_summary WHERE Order_ID = p_order_id;
END$$

-- ---------------------------------------------------------------------
-- sp_cancel_order: only Pending or Paid orders can be cancelled
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_cancel_order(IN p_order_id INT)
BEGIN
    DECLARE v_status VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT Order_Status INTO v_status FROM Orders WHERE Order_ID = p_order_id;
    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order not found';
    ELSEIF v_status NOT IN ('Pending', 'Paid') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only Pending or Paid orders can be cancelled';
    END IF;

    START TRANSACTION;
    -- refund trigger returns card money and takes back earned points
    UPDATE Payment SET Payment_Status = 'Refunded'
    WHERE Order_ID = p_order_id AND Payment_Status = 'Success';

    UPDATE Orders        SET Order_Status = 'Cancelled' WHERE Order_ID = p_order_id;
    UPDATE Delivery      SET Delivery_Status = 'Failed' WHERE Order_ID = p_order_id;
    COMMIT;

    SELECT o.Order_ID, o.Order_Status, p.Payment_Status, p.Payment_Method, p.Amount AS Refunded_Amount
    FROM Orders o LEFT JOIN Payment p ON p.Order_ID = o.Order_ID
    WHERE o.Order_ID = p_order_id;
END$$

-- ---------------------------------------------------------------------
-- sp_redeem_points
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_redeem_points(IN p_member_id INT, IN p_points INT)
BEGIN
    DECLARE v_points INT;
    DECLARE v_status VARCHAR(20);

    SELECT Points, Member_Status INTO v_points, v_status FROM Member WHERE Member_ID = p_member_id;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Member not found';
    ELSEIF v_status <> 'Active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Member account is not active';
    ELSEIF p_points IS NULL OR p_points <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Points to redeem must be positive';
    ELSEIF p_points > v_points THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Not enough points';
    END IF;

    -- trg_point_txn_ai updates Member.Points
    INSERT INTO Point_Transaction (Member_ID, Order_ID, Txn_Type, Points_Change)
    VALUES (p_member_id, NULL, 'Redeem', -p_points);

    SELECT Member_ID, Member_Name, Points AS Points_Left FROM Member WHERE Member_ID = p_member_id;
END$$

-- ---------------------------------------------------------------------
-- sp_branch_report: KPIs, top 5 products, orders by hour
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_branch_report(IN p_branch_id INT, IN p_from DATE, IN p_to DATE)
BEGIN
    -- 1) headline numbers
    SELECT b.Branch_Name,
           p_from AS From_Date, p_to AS To_Date,
           COUNT(*)                                                   AS Orders,
           SUM(o.Order_Status = 'Cancelled')                          AS Cancelled,
           SUM(CASE WHEN o.Order_Status <> 'Cancelled' THEN o.Order_Amount END) AS Gross_Sales,
           ROUND(AVG(CASE WHEN o.Order_Status <> 'Cancelled' THEN o.Order_Amount END), 2) AS Avg_Order_Value,
           COUNT(DISTINCT o.Member_ID)                                AS Unique_Customers
    FROM Orders o
    JOIN Branch b ON b.Branch_ID = o.Branch_ID
    WHERE o.Branch_ID = p_branch_id
      AND o.Order_DateTime >= p_from
      AND o.Order_DateTime <  p_to + INTERVAL 1 DAY
    GROUP BY b.Branch_Name;

    -- 2) top 5 products
    SELECT p.Product_Name, SUM(i.Quantity) AS Units, SUM(i.Line_Total) AS Revenue
    FROM Orders o
    JOIN Order_Item i ON i.Order_ID = o.Order_ID
    JOIN Product p    ON p.Product_ID = i.Product_ID
    WHERE o.Branch_ID = p_branch_id
      AND o.Order_Status <> 'Cancelled'
      AND o.Order_DateTime >= p_from
      AND o.Order_DateTime <  p_to + INTERVAL 1 DAY
    GROUP BY p.Product_ID, p.Product_Name
    ORDER BY Units DESC
    LIMIT 5;

    -- 3) orders by hour
    SELECT HOUR(Order_DateTime) AS Hour_Of_Day, COUNT(*) AS Orders
    FROM Orders
    WHERE Branch_ID = p_branch_id
      AND Order_DateTime >= p_from
      AND Order_DateTime <  p_to + INTERVAL 1 DAY
    GROUP BY HOUR(Order_DateTime)
    ORDER BY Hour_Of_Day;
END$$

DELIMITER ;
