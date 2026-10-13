-- =====================================================================
-- Coffee Chain Database — Schema v2
-- MySQL 8.0+
--
-- Redesign of the ITCS216 group project (v1: v1-original/pj2sec02gr09db.sql)
-- Change log (numbers match docs/schema-v2-decisions.xlsx):
--   #1  Order_DateTime, Pickup_Time: DATE -> DATETIME
--   #2  Contain -> Order_Item with its own surrogate key (Order_Item_ID)
--   #3  Product.Base_Price added; Order_Item.Unit_Price keeps price at time of sale
--   #4  Promotion.Discount_Value added
--   #5  Orders.Order_Amount maintained by triggers on Order_Item
--   #6  Promotion.Promotion_Status removed -> computed in view v_promotion_status
--   #7  UNIQUE on Member.Email and Member.Phone_Number
--   #8  Delivery table + 'Delivery' order type
--   #9  Starbucks_Card table
--   #10 Payment table
--   #11 Point_Transaction table (points history)
--   #12 Orders.Promotion_ID (which promotion was applied)
--   #13 AUTO_INCREMENT surrogate keys
--   #14 `Order` -> Orders (ORDER is a reserved word)
--   #15 Member_Address gets Address_ID and split address fields
--   #16 Branch.Opening_Hours -> Open_Time / Close_Time (TIME)
--   Also: E_mail renamed to Email; Receipt one-per-order (UNIQUE Order_ID)
-- =====================================================================

DROP DATABASE IF EXISTS coffee_chain_db;
CREATE DATABASE coffee_chain_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;
USE coffee_chain_db;
SET NAMES utf8mb4;   -- make sure accented names (Caffè, Açaí) are stored correctly

-- =====================================================================
-- MASTER TABLES
-- =====================================================================

-- Member: registered customers
CREATE TABLE Member (
    Member_ID          INT           NOT NULL AUTO_INCREMENT,
    Member_Name        VARCHAR(100)  NOT NULL,
    Email              VARCHAR(100)  NULL,
    Phone_Number       VARCHAR(15)   NULL,
    Date_of_Birth      DATE          NULL,
    Points             INT           NOT NULL DEFAULT 0,   -- current balance; history in Point_Transaction
    Registration_Date  DATE          NOT NULL,
    Member_Level       VARCHAR(20)   NOT NULL DEFAULT 'Green',
    Member_Status      VARCHAR(20)   NOT NULL DEFAULT 'Active',
    CONSTRAINT PK_Member             PRIMARY KEY (Member_ID),
    CONSTRAINT UQ_Member_Email       UNIQUE (Email),                                -- #7
    CONSTRAINT UQ_Member_Phone       UNIQUE (Phone_Number),                         -- #7
    CONSTRAINT CHK_Member_Level      CHECK (Member_Level IN ('Green','Gold')),
    CONSTRAINT CHK_Member_Status     CHECK (Member_Status IN ('Active','Inactive','Banned')),
    CONSTRAINT CHK_Member_Points     CHECK (Points >= 0)
) AUTO_INCREMENT = 100001;

-- Member_Address: saved delivery addresses (a member can have many)      #15
CREATE TABLE Member_Address (
    Address_ID     INT           NOT NULL AUTO_INCREMENT,
    Member_ID      INT           NOT NULL,
    Label          VARCHAR(30)   NULL,              -- e.g. Home, Work
    Address_Line   VARCHAR(200)  NOT NULL,          -- house no., street, soi
    District       VARCHAR(100)  NULL,
    Province       VARCHAR(100)  NOT NULL,
    Postal_Code    CHAR(5)       NULL,
    Is_Default     TINYINT(1)    NOT NULL DEFAULT 0,
    CONSTRAINT PK_Member_Address        PRIMARY KEY (Address_ID),
    CONSTRAINT FK_Member_Address_Member FOREIGN KEY (Member_ID)
        REFERENCES Member(Member_ID)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT CHK_Address_Is_Default   CHECK (Is_Default IN (0,1))
);

-- Product: menu items and merchandise
CREATE TABLE Product (
    Product_ID           INT           NOT NULL AUTO_INCREMENT,
    Product_Name         VARCHAR(100)  NOT NULL,
    Product_Description  VARCHAR(255)  NULL,
    Type_Product         VARCHAR(30)   NOT NULL,
    Base_Price           DECIMAL(8,2)  NOT NULL,                                   -- #3
    Is_Active            TINYINT(1)    NOT NULL DEFAULT 1,
    Is_Seasonal          TINYINT(1)    NOT NULL DEFAULT 0,
    CONSTRAINT PK_Product              PRIMARY KEY (Product_ID),
    CONSTRAINT CHK_Type_Product        CHECK (Type_Product IN ('Beverage','Food','Merch')),
    CONSTRAINT CHK_Product_Base_Price  CHECK (Base_Price >= 0),
    CONSTRAINT CHK_Product_Is_Active   CHECK (Is_Active IN (0,1)),
    CONSTRAINT CHK_Product_Is_Seasonal CHECK (Is_Seasonal IN (0,1))
) AUTO_INCREMENT = 200001;

-- Branch: stores
CREATE TABLE Branch (
    Branch_ID       INT           NOT NULL AUTO_INCREMENT,
    Branch_Name     VARCHAR(100)  NOT NULL,
    Location        VARCHAR(200)  NOT NULL,
    Open_Time       TIME          NULL,                                             -- #16
    Close_Time      TIME          NULL,                                             -- #16
    Contact_Number  VARCHAR(15)   NULL,
    Store_Type      VARCHAR(30)   NOT NULL,
    Branch_Manager  VARCHAR(100)  NULL,
    Branch_Status   VARCHAR(20)   NOT NULL DEFAULT 'Open',
    CONSTRAINT PK_Branch          PRIMARY KEY (Branch_ID),
    CONSTRAINT CHK_Store_Type     CHECK (Store_Type IN ('Drive Thru','Coffee House')),
    CONSTRAINT CHK_Branch_Status  CHECK (Branch_Status IN ('Open','Closed','Renovation'))
) AUTO_INCREMENT = 1001;

-- Promotion: status is NOT stored; see view v_promotion_status            #6
CREATE TABLE Promotion (
    Promotion_ID    INT           NOT NULL AUTO_INCREMENT,
    Promotion_Name  VARCHAR(100)  NOT NULL,
    Description     VARCHAR(255)  NULL,
    Discount_Type   VARCHAR(20)   NOT NULL,
    Discount_Value  DECIMAL(8,2)  NOT NULL,                                         -- #4
    Start_Date      DATE          NOT NULL,
    End_Date        DATE          NOT NULL,
    CONSTRAINT PK_Promotion             PRIMARY KEY (Promotion_ID),
    -- Percent = % off, Baht = fixed amount off, Point_Multiplier = e.g. 2 for double points
    CONSTRAINT CHK_Discount_Type        CHECK (Discount_Type IN ('Percent','Baht','Point_Multiplier')),
    CONSTRAINT CHK_Discount_Value       CHECK (Discount_Value > 0),
    CONSTRAINT CHK_Discount_Percent_Max CHECK (Discount_Type <> 'Percent' OR Discount_Value <= 100),
    CONSTRAINT CHK_Promotion_Dates      CHECK (End_Date >= Start_Date)
) AUTO_INCREMENT = 300001;

-- Starbucks_Card: stored-value cards owned by members                     #9
CREATE TABLE Starbucks_Card (
    Card_ID      INT            NOT NULL AUTO_INCREMENT,
    Card_Number  CHAR(16)       NOT NULL,
    Member_ID    INT            NOT NULL,
    Balance      DECIMAL(10,2)  NOT NULL DEFAULT 0,
    Card_Status  VARCHAR(20)    NOT NULL DEFAULT 'Active',
    Issued_Date  DATE           NOT NULL,
    CONSTRAINT PK_Starbucks_Card      PRIMARY KEY (Card_ID),
    CONSTRAINT UQ_Card_Number         UNIQUE (Card_Number),
    CONSTRAINT FK_Card_Member         FOREIGN KEY (Member_ID)
        REFERENCES Member(Member_ID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT CHK_Card_Balance       CHECK (Balance >= 0),
    CONSTRAINT CHK_Card_Status        CHECK (Card_Status IN ('Active','Blocked','Expired'))
) AUTO_INCREMENT = 600001;

-- =====================================================================
-- TRANSACTION TABLES
-- =====================================================================

-- Orders (renamed from `Order`)                                           #14
CREATE TABLE Orders (
    Order_ID        INT            NOT NULL AUTO_INCREMENT,
    Member_ID       INT            NOT NULL,
    Branch_ID       INT            NOT NULL,
    Promotion_ID    INT            NULL,                                            -- #12
    Order_Type      VARCHAR(20)    NOT NULL,
    Order_Status    VARCHAR(20)    NOT NULL DEFAULT 'Pending',
    Order_DateTime  DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,              -- #1
    Order_Amount    DECIMAL(10,2)  NOT NULL DEFAULT 0,  -- sum of Order_Item.Line_Total, kept by triggers (#5)
    CONSTRAINT PK_Orders            PRIMARY KEY (Order_ID),
    CONSTRAINT FK_Orders_Member     FOREIGN KEY (Member_ID)
        REFERENCES Member(Member_ID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT FK_Orders_Branch     FOREIGN KEY (Branch_ID)
        REFERENCES Branch(Branch_ID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT FK_Orders_Promotion  FOREIGN KEY (Promotion_ID)
        REFERENCES Promotion(Promotion_ID)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT CHK_Order_Type       CHECK (Order_Type IN ('InStorePickup','OrderToTable','Delivery')),   -- #8
    CONSTRAINT CHK_Order_Status     CHECK (Order_Status IN ('Pending','Paid','Completed','Cancelled'))
) AUTO_INCREMENT = 400001;

-- Order_Item (was Contain): one row per line in an order                 #2
CREATE TABLE Order_Item (
    Order_Item_ID  INT            NOT NULL AUTO_INCREMENT,
    Order_ID       INT            NOT NULL,
    Product_ID     INT            NOT NULL,
    Size           VARCHAR(10)    NULL,
    Customize      VARCHAR(200)   NULL,
    Quantity       INT            NOT NULL,
    Unit_Price     DECIMAL(8,2)   NOT NULL,      -- price at time of sale (#3)
    Line_Total     DECIMAL(10,2)  AS (Quantity * Unit_Price) STORED,
    CONSTRAINT PK_Order_Item          PRIMARY KEY (Order_Item_ID),
    CONSTRAINT FK_Order_Item_Order    FOREIGN KEY (Order_ID)
        REFERENCES Orders(Order_ID)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT FK_Order_Item_Product  FOREIGN KEY (Product_ID)
        REFERENCES Product(Product_ID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT CHK_Quantity           CHECK (Quantity BETWEEN 1 AND 99),
    CONSTRAINT CHK_Unit_Price         CHECK (Unit_Price >= 0),
    CONSTRAINT CHK_Size               CHECK (Size IN ('Short','Tall','Grande','Venti'))
);

-- Order subtypes (one row per order, matching Order_Type) ---------------

CREATE TABLE InStorePickup (
    Order_ID       INT          NOT NULL,
    Pickup_Time    DATETIME     NULL,                                               -- #1
    Pickup_Status  VARCHAR(20)  NOT NULL DEFAULT 'Waiting',
    CONSTRAINT PK_InStorePickup        PRIMARY KEY (Order_ID),
    CONSTRAINT FK_InStorePickup_Order  FOREIGN KEY (Order_ID)
        REFERENCES Orders(Order_ID)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT CHK_Pickup_Status       CHECK (Pickup_Status IN ('Waiting','Picked','Late'))
);

CREATE TABLE OrderToTable (
    Order_ID      INT  NOT NULL,
    Table_Number  INT  NOT NULL,
    CONSTRAINT PK_OrderToTable        PRIMARY KEY (Order_ID),
    CONSTRAINT FK_OrderToTable_Order  FOREIGN KEY (Order_ID)
        REFERENCES Orders(Order_ID)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT CHK_Table_Number       CHECK (Table_Number > 0)
);

-- Delivery                                                                #8
-- Address is copied (snapshot) from Member_Address at order time, so the
-- order history stays correct even if the member later edits/deletes the address.
CREATE TABLE Delivery (
    Order_ID          INT           NOT NULL,
    Delivery_Address  VARCHAR(255)  NOT NULL,
    Contact_Phone     VARCHAR(15)   NOT NULL,
    Delivery_Fee      DECIMAL(8,2)  NOT NULL DEFAULT 0,
    Delivery_Status   VARCHAR(20)   NOT NULL DEFAULT 'Preparing',
    Delivered_At      DATETIME      NULL,
    CONSTRAINT PK_Delivery           PRIMARY KEY (Order_ID),
    CONSTRAINT FK_Delivery_Order     FOREIGN KEY (Order_ID)
        REFERENCES Orders(Order_ID)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT CHK_Delivery_Fee      CHECK (Delivery_Fee >= 0),
    CONSTRAINT CHK_Delivery_Status   CHECK (Delivery_Status IN ('Preparing','On the way','Delivered','Failed'))
);

-- Receipt (one per order)
CREATE TABLE Receipt (
    Receipt_ID        INT           NOT NULL AUTO_INCREMENT,
    Order_ID          INT           NOT NULL,
    Receipt_DateTime  DATETIME      NOT NULL,
    Tax_ID            CHAR(13)      NULL,          -- customer tax ID for a full tax invoice
    Tax_Address       VARCHAR(200)  NULL,
    Discount          DECIMAL(8,2)  NOT NULL DEFAULT 0,
    CONSTRAINT PK_Receipt        PRIMARY KEY (Receipt_ID),
    CONSTRAINT UQ_Receipt_Order  UNIQUE (Order_ID),
    CONSTRAINT FK_Receipt_Order  FOREIGN KEY (Order_ID)
        REFERENCES Orders(Order_ID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT CHK_Receipt_Discount CHECK (Discount >= 0)
) AUTO_INCREMENT = 500001;

-- Payment                                                                 #10
-- Card_ID is required when paying by Starbucks Card and must be NULL otherwise.
-- (MySQL forbids ON DELETE/UPDATE actions on a column used in a CHECK, so the
--  FK on Card_ID uses the default behaviour: deleting a used card is blocked.)
CREATE TABLE Payment (
    Payment_ID      INT            NOT NULL AUTO_INCREMENT,
    Order_ID        INT            NOT NULL,
    Payment_Method  VARCHAR(20)    NOT NULL,
    Card_ID         INT            NULL,
    Amount          DECIMAL(10,2)  NOT NULL,
    Paid_At         DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Payment_Status  VARCHAR(20)    NOT NULL DEFAULT 'Success',
    CONSTRAINT PK_Payment          PRIMARY KEY (Payment_ID),
    CONSTRAINT FK_Payment_Order    FOREIGN KEY (Order_ID)
        REFERENCES Orders(Order_ID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT FK_Payment_Card     FOREIGN KEY (Card_ID)
        REFERENCES Starbucks_Card(Card_ID),
    CONSTRAINT CHK_Payment_Method  CHECK (Payment_Method IN ('StarbucksCard','CreditCard','Cash','QR')),
    CONSTRAINT CHK_Payment_Card    CHECK ((Payment_Method = 'StarbucksCard') = (Card_ID IS NOT NULL)),
    CONSTRAINT CHK_Payment_Amount  CHECK (Amount > 0),
    CONSTRAINT CHK_Payment_Status  CHECK (Payment_Status IN ('Success','Failed','Refunded'))
) AUTO_INCREMENT = 700001;

-- Point_Transaction: every change to a member's points                   #11
CREATE TABLE Point_Transaction (
    Txn_ID         INT          NOT NULL AUTO_INCREMENT,
    Member_ID      INT          NOT NULL,
    Order_ID       INT          NULL,             -- NULL for manual adjustments / expiry
    Txn_Type       VARCHAR(20)  NOT NULL,
    Points_Change  INT          NOT NULL,         -- positive = earn, negative = redeem/expire
    Created_At     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT PK_Point_Transaction  PRIMARY KEY (Txn_ID),
    CONSTRAINT FK_PointTxn_Member    FOREIGN KEY (Member_ID)
        REFERENCES Member(Member_ID)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT FK_PointTxn_Order     FOREIGN KEY (Order_ID)
        REFERENCES Orders(Order_ID)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT CHK_PointTxn_Type     CHECK (Txn_Type IN ('Earn','Redeem','Adjust','Expire')),
    CONSTRAINT CHK_PointTxn_Change   CHECK (Points_Change <> 0)
);

-- Offer: which promotion applies to which product at which branch (unchanged)
CREATE TABLE Offer (
    Product_ID    INT   NOT NULL,
    Branch_ID     INT   NOT NULL,
    Promotion_ID  INT   NOT NULL,
    Created_Date  DATE  NOT NULL,
    CONSTRAINT PK_Offer            PRIMARY KEY (Product_ID, Branch_ID, Promotion_ID),
    CONSTRAINT FK_Offer_Product    FOREIGN KEY (Product_ID)
        REFERENCES Product(Product_ID)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT FK_Offer_Branch     FOREIGN KEY (Branch_ID)
        REFERENCES Branch(Branch_ID)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT FK_Offer_Promotion  FOREIGN KEY (Promotion_ID)
        REFERENCES Promotion(Promotion_ID)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- =====================================================================
-- VIEW: promotion status computed from dates                             #6
-- =====================================================================
CREATE VIEW v_promotion_status AS
SELECT
    p.*,
    CASE
        WHEN CURDATE() < p.Start_Date THEN 'Upcoming'
        WHEN CURDATE() > p.End_Date   THEN 'Ended'
        ELSE 'Active'
    END AS Promotion_Status
FROM Promotion p;

-- =====================================================================
-- TRIGGERS: keep Orders.Order_Amount = SUM(Order_Item.Line_Total)        #5
-- =====================================================================
DELIMITER $$

CREATE TRIGGER trg_order_item_ai
AFTER INSERT ON Order_Item
FOR EACH ROW
BEGIN
    UPDATE Orders
    SET Order_Amount = (SELECT COALESCE(SUM(Line_Total), 0)
                        FROM Order_Item WHERE Order_ID = NEW.Order_ID)
    WHERE Order_ID = NEW.Order_ID;
END$$

CREATE TRIGGER trg_order_item_au
AFTER UPDATE ON Order_Item
FOR EACH ROW
BEGIN
    UPDATE Orders
    SET Order_Amount = (SELECT COALESCE(SUM(Line_Total), 0)
                        FROM Order_Item WHERE Order_ID = NEW.Order_ID)
    WHERE Order_ID = NEW.Order_ID;
    -- if the item was moved to another order, fix the old order too
    IF OLD.Order_ID <> NEW.Order_ID THEN
        UPDATE Orders
        SET Order_Amount = (SELECT COALESCE(SUM(Line_Total), 0)
                            FROM Order_Item WHERE Order_ID = OLD.Order_ID)
        WHERE Order_ID = OLD.Order_ID;
    END IF;
END$$

CREATE TRIGGER trg_order_item_ad
AFTER DELETE ON Order_Item
FOR EACH ROW
BEGIN
    UPDATE Orders
    SET Order_Amount = (SELECT COALESCE(SUM(Line_Total), 0)
                        FROM Order_Item WHERE Order_ID = OLD.Order_ID)
    WHERE Order_ID = OLD.Order_ID;
END$$

DELIMITER ;
