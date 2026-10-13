-- =====================================================================
-- Coffee Chain Database — Small seed data (for v2 schema)
-- Run AFTER schema/schema_v2.sql
--
-- Migrated from v1 sample data, with these fixes:
--   * Products now have realistic Base_Price; Unit_Price = Base_Price + size upcharge
--     (Short -10, Tall +0, Grande +15, Venti +30)
--   * Order_Amount is NOT inserted: triggers compute it from Order_Item
--   * Orders/pickups have real times (DATETIME)
--   * Receipt discounts now come from an actual promotion (Orders.Promotion_ID)
--   * Cancelled orders have no receipt, payment or points
--   * Member.Points is rebuilt from Point_Transaction (opening balance = v1 points)
--   * New: deliveries, Starbucks cards, payments, point history, 2 promotions for 2026-27
-- =====================================================================
USE coffee_chain_db;
-- Workbench enables safe-update mode by default, which blocks the bulk UPDATEs below
SET SQL_SAFE_UPDATES = 0;

-- ---------------------------------------------------------------------
-- Member
-- ---------------------------------------------------------------------
INSERT INTO Member (Member_ID, Member_Name, Email, Phone_Number, Date_of_Birth, Registration_Date, Member_Level, Member_Status) VALUES
(100001, 'John Smith',         'john.smith@example.com',         '0891234567', '1990-01-15', '2024-01-01', 'Green', 'Active'),
(100002, 'Emma Brown',         'emma.brown@example.com',         '0891234568', '1991-02-15', '2024-02-01', 'Green', 'Active'),
(100003, 'Michael Johnson',    'michael.johnson@example.com',    '0891234569', '1992-03-15', '2024-03-01', 'Green', 'Active'),
(100004, 'Olivia Williams',    'olivia.williams@example.com',    '0891234570', '1993-04-15', '2024-04-01', 'Green', 'Active'),
(100005, 'Liam Taylor',        'liam.taylor@example.com',        '0891234571', '1994-05-15', '2024-05-01', 'Green', 'Active'),
(100006, 'Sophia Martinez',    'sophia.martinez@example.com',    '0891234572', '1995-06-15', '2024-06-01', 'Gold',  'Active'),
(100007, 'Daniel Garcia',      'daniel.garcia@example.com',      '0891234573', '1996-07-15', '2024-07-01', 'Gold',  'Active'),
(100008, 'Isabella Rodriguez', 'isabella.rodriguez@example.com', '0891234574', '1997-08-15', '2024-08-01', 'Gold',  'Active'),
(100009, 'Ethan Lee',          'ethan.lee@example.com',          '0891234575', '1998-09-15', '2024-09-01', 'Gold',  'Active'),
(100010, 'Ava Wilson',         'ava.wilson@example.com',         '0891234576', '1999-01-15', '2024-01-01', 'Gold',  'Active');

-- ---------------------------------------------------------------------
-- Member_Address (split into fields)
-- ---------------------------------------------------------------------
INSERT INTO Member_Address (Member_ID, Label, Address_Line, District, Province, Postal_Code, Is_Default) VALUES
(100001, 'Home', '100/1 Sukhumvit 63 Rd',     'Watthana',     'Bangkok',            '10110', 1),
(100001, 'Work', '999 Rama 1 Rd',             'Pathum Wan',   'Bangkok',            '10330', 0),
(100002, 'Home', '123/2 Ratchaphruek Rd',     'Taling Chan',  'Bangkok',            '10170', 1),
(100003, 'Home', '45 Soi Ramkhamhaeng 24',    'Suan Luang',   'Bangkok',            '10250', 1),
(100004, 'Home', '88/4 Phahonyothin Rd',      'Chatuchak',    'Bangkok',            '10900', 1),
(100005, 'Home', '12/8 Phaya Thai Rd',        'Ratchathewi',  'Bangkok',            '10400', 1),
(100006, 'Home', '321/7 Silom Rd',            'Bang Rak',     'Bangkok',            '10500', 1),
(100007, 'Home', '250/5 Rama 2 Rd',           'Bang Khun Thian', 'Bangkok',         '10150', 1),
(100008, 'Home', '16/3 Sukhumvit 71 Rd',      'Watthana',     'Bangkok',            '10110', 1),
(100009, 'Home', '90/2 Sathorn Rd',           'Sathon',       'Bangkok',            '10120', 1),
(100010, 'Home', '55/10 Mittraphap Rd',       'Pak Chong',    'Nakhon Ratchasima',  '30130', 1);

-- ---------------------------------------------------------------------
-- Product (Base_Price = Tall size / single item)
-- ---------------------------------------------------------------------
INSERT INTO Product (Product_ID, Product_Name, Product_Description, Type_Product, Base_Price, Is_Active, Is_Seasonal) VALUES
(200001, 'Caffè Americano',        'Hot espresso with hot water',                  'Beverage', 110.00, 1, 0),
(200002, 'Caffè Latte',            'Espresso with steamed milk',                   'Beverage', 125.00, 1, 0),
(200003, 'Caramel Macchiato',      'Espresso with vanilla, milk, caramel drizzle', 'Beverage', 140.00, 1, 0),
(200004, 'Green Tea Frappuccino',  'Blended matcha beverage',                      'Beverage', 150.00, 1, 1),
(200005, 'Chocolate Chunk Cookie', 'Baked cookie with chocolate chunks',           'Food',      75.00, 1, 0),
(200006, 'Blueberry Cheesecake',   'Slice of blueberry cheesecake',                'Food',     135.00, 1, 0),
(200007, 'Ham & Cheese Croissant', 'Croissant with ham and cheese',                'Food',      95.00, 1, 0),
(200008, 'Reusable Cold Cup 24oz', 'Plastic reusable cold cup',                    'Merch',    450.00, 1, 0),
(200009, 'Starbucks Mug 12oz',     'Ceramic mug',                                  'Merch',    590.00, 1, 0),
(200010, 'Pumpkin Spice Latte',    'Seasonal pumpkin spice latte',                 'Beverage', 160.00, 0, 1);

-- ---------------------------------------------------------------------
-- Branch
-- ---------------------------------------------------------------------
INSERT INTO Branch (Branch_ID, Branch_Name, Location, Open_Time, Close_Time, Contact_Number, Store_Type, Branch_Manager, Branch_Status) VALUES
(1001, 'Starbucks Siam Paragon',      'Siam Paragon, Bangkok', '07:00', '22:00', '021234567', 'Coffee House', 'Somchai A.', 'Open'),
(1002, 'Starbucks CentralWorld',      'CentralWorld, Bangkok', '08:00', '22:00', '021234568', 'Coffee House', 'Suda B.',    'Open'),
(1003, 'Starbucks Drive Thru Rama 2', 'Rama 2 Rd, Bangkok',    '06:30', '21:30', '021234569', 'Drive Thru',   'Anan C.',    'Open'),
(1004, 'Starbucks ICONSIAM',          'ICONSIAM, Bangkok',     '08:00', '23:00', '021234570', 'Coffee House', 'Ploy D.',    'Open'),
(1005, 'Starbucks Chiang Mai Nimman', 'Nimman Rd, Chiang Mai', '07:00', '21:00', '053123456', 'Coffee House', 'Napat E.',   'Renovation');

-- ---------------------------------------------------------------------
-- Promotion (status comes from v_promotion_status)
-- ---------------------------------------------------------------------
INSERT INTO Promotion (Promotion_ID, Promotion_Name, Description, Discount_Type, Discount_Value, Start_Date, End_Date) VALUES
(300001, 'Happy Morning 10% Off',       '10% off all hot coffees before 11 AM',     'Percent',          10.00, '2025-10-01', '2025-10-31'),
(300002, 'Buy 1 Get 1 Frappuccino',     'Buy one get one on selected Frappuccino',  'Percent',          50.00, '2025-11-01', '2025-11-07'),
(300003, 'Green Level Welcome 50 Baht', '50 THB discount for new Green members',    'Baht',             50.00, '2025-01-01', '2025-12-31'),
(300004, 'Gold Member Double Stars',    'Double points for Gold members',           'Point_Multiplier',  2.00, '2025-11-01', '2025-11-30'),
(300005, 'Holiday Season Set',          'Discounted drink + dessert set',           'Baht',             40.00, '2025-12-01', '2025-12-31'),
(300006, 'Rainy Season 15% Off',        '15% off all hot beverages',                'Percent',          15.00, '2026-06-01', '2026-12-31'),
(300007, 'New Year 2027 Treat',         '60 THB off orders over 300 THB',           'Baht',             60.00, '2027-01-01', '2027-01-15');

-- ---------------------------------------------------------------------
-- Offer
-- ---------------------------------------------------------------------
INSERT INTO Offer (Product_ID, Branch_ID, Promotion_ID, Created_Date) VALUES
(200001, 1001, 300001, '2025-10-01'),
(200002, 1001, 300002, '2025-11-01'),
(200004, 1002, 300002, '2025-11-01'),
(200010, 1003, 300005, '2025-12-01'),
(200005, 1004, 300003, '2025-01-05'),
(200006, 1004, 300005, '2025-12-01'),
(200007, 1002, 300004, '2025-11-05'),
(200008, 1005, 300003, '2025-02-01'),
(200001, 1004, 300006, '2026-06-01'),
(200002, 1004, 300006, '2026-06-01');

-- ---------------------------------------------------------------------
-- Starbucks_Card
-- ---------------------------------------------------------------------
INSERT INTO Starbucks_Card (Card_ID, Card_Number, Member_ID, Balance, Card_Status, Issued_Date) VALUES
(600001, '6012000000000001', 100001,  500.00, 'Active',  '2024-01-05'),
(600002, '6012000000000002', 100002, 1200.00, 'Active',  '2024-02-10'),
(600003, '6012000000000003', 100006,  800.00, 'Active',  '2024-06-03'),
(600004, '6012000000000004', 100006,    0.00, 'Expired', '2022-06-03'),
(600005, '6012000000000005', 100008,  350.00, 'Active',  '2024-08-20'),
(600006, '6012000000000006', 100010,  150.00, 'Blocked', '2024-01-02');

-- ---------------------------------------------------------------------
-- Orders  (Order_Amount filled in automatically by triggers)
-- ---------------------------------------------------------------------
INSERT INTO Orders (Order_ID, Member_ID, Branch_ID, Promotion_ID, Order_Type, Order_Status, Order_DateTime) VALUES
(400001, 100001, 1001, 300003, 'InStorePickup', 'Paid',      '2025-11-01 08:15:00'),
(400002, 100002, 1002, NULL,   'OrderToTable',  'Paid',      '2025-11-02 10:40:00'),
(400003, 100003, 1003, NULL,   'InStorePickup', 'Paid',      '2025-11-03 07:05:00'),
(400004, 100004, 1004, 300003, 'OrderToTable',  'Paid',      '2025-11-04 13:20:00'),
(400005, 100005, 1005, NULL,   'InStorePickup', 'Paid',      '2025-11-05 16:45:00'),
(400006, 100006, 1001, NULL,   'OrderToTable',  'Paid',      '2025-11-01 12:10:00'),
(400007, 100007, 1002, 300004, 'InStorePickup', 'Paid',      '2025-11-02 09:30:00'),
(400008, 100008, 1001, NULL,   'OrderToTable',  'Paid',      '2025-11-03 18:00:00'),  -- v1 had this at a Drive Thru (1003)
(400009, 100009, 1004, NULL,   'InStorePickup', 'Paid',      '2025-11-04 08:50:00'),
(400010, 100010, 1005, 300004, 'OrderToTable',  'Paid',      '2025-11-05 14:15:00'),
(400011, 100001, 1001, NULL,   'InStorePickup', 'Completed', '2025-11-01 17:25:00'),
(400012, 100002, 1002, NULL,   'OrderToTable',  'Completed', '2025-11-02 11:05:00'),
(400013, 100003, 1003, 300003, 'InStorePickup', 'Completed', '2025-11-03 07:40:00'),
(400014, 100004, 1004, NULL,   'OrderToTable',  'Cancelled', '2025-11-04 19:30:00'),
(400015, 100005, 1005, NULL,   'InStorePickup', 'Cancelled', '2025-11-05 10:00:00'),
(400016, 100006, 1001, NULL,   'Delivery',      'Completed', '2025-11-06 12:30:00'),
(400017, 100008, 1004, NULL,   'Delivery',      'Completed', '2025-11-07 19:10:00'),
(400018, 100010, 1002, NULL,   'Delivery',      'Cancelled', '2025-11-08 20:45:00');

-- ---------------------------------------------------------------------
-- Order_Item (Unit_Price = Base_Price + size upcharge)
-- ---------------------------------------------------------------------
INSERT INTO Order_Item (Order_ID, Product_ID, Size, Customize, Quantity, Unit_Price) VALUES
(400001, 200001, 'Tall',   NULL,           1, 110.00),
(400001, 200002, 'Grande', 'Less ice',     2, 140.00),
(400002, 200003, 'Venti',  'Non-fat milk', 3, 170.00),
(400002, 200004, 'Tall',   'Extra shot',   1, 150.00),
(400003, 200005, NULL,     NULL,           2,  75.00),
(400003, 200006, NULL,     NULL,           3, 135.00),
(400004, 200007, NULL,     NULL,           1,  95.00),
(400004, 200008, NULL,     NULL,           2, 450.00),
(400005, 200009, NULL,     NULL,           3, 590.00),
(400005, 200010, 'Tall',   'Extra shot',   1, 160.00),
(400006, 200001, 'Grande', NULL,           2, 125.00),
(400006, 200002, 'Venti',  'Non-fat milk', 3, 155.00),
(400007, 200003, 'Tall',   'Extra shot',   1, 140.00),
(400007, 200004, 'Grande', 'Less ice',     2, 165.00),
(400008, 200005, NULL,     NULL,           3,  75.00),
(400008, 200006, NULL,     NULL,           1, 135.00),
(400009, 200007, NULL,     NULL,           2,  95.00),
(400009, 200008, NULL,     NULL,           3, 450.00),
(400010, 200009, NULL,     NULL,           1, 590.00),
(400010, 200010, 'Grande', 'Less ice',     2, 175.00),
(400011, 200001, 'Venti',  NULL,           3, 140.00),
(400011, 200002, 'Tall',   'Extra shot',   1, 125.00),
(400012, 200003, 'Grande', 'Less ice',     2, 155.00),
(400012, 200004, 'Venti',  'Non-fat milk', 3, 180.00),
(400013, 200005, NULL,     NULL,           1,  75.00),
(400013, 200006, NULL,     NULL,           2, 135.00),
(400014, 200007, NULL,     NULL,           3,  95.00),
(400014, 200008, NULL,     NULL,           1, 450.00),
(400015, 200009, NULL,     NULL,           2, 590.00),
(400015, 200010, 'Venti',  'Non-fat milk', 3, 190.00),
-- same product twice in one order with different customisation (impossible in v1)
(400016, 200002, 'Grande', 'Oat milk',     1, 140.00),
(400016, 200002, 'Grande', NULL,           1, 140.00),
(400016, 200007, NULL,     NULL,           2,  95.00),
(400017, 200003, 'Venti',  NULL,           2, 170.00),
(400017, 200006, NULL,     NULL,           1, 135.00),
(400018, 200001, 'Tall',   NULL,           1, 110.00);

-- ---------------------------------------------------------------------
-- Order subtypes
-- ---------------------------------------------------------------------
INSERT INTO InStorePickup (Order_ID, Pickup_Time, Pickup_Status) VALUES
(400001, '2025-11-01 08:25:00', 'Picked'),
(400003, '2025-11-03 07:12:00', 'Picked'),
(400005, NULL,                  'Waiting'),
(400007, '2025-11-02 09:55:00', 'Late'),
(400009, '2025-11-04 09:00:00', 'Picked'),
(400011, '2025-11-01 17:35:00', 'Picked'),
(400013, '2025-11-03 07:48:00', 'Picked'),
(400015, NULL,                  'Waiting');

INSERT INTO OrderToTable (Order_ID, Table_Number) VALUES
(400002, 2), (400004, 4), (400006, 6), (400008, 8), (400010, 10), (400012, 2), (400014, 5);

INSERT INTO Delivery (Order_ID, Delivery_Address, Contact_Phone, Delivery_Fee, Delivery_Status, Delivered_At) VALUES
(400016, '321/7 Silom Rd, Bang Rak, Bangkok 10500',        '0891234572', 30.00, 'Delivered', '2025-11-06 13:05:00'),
(400017, '16/3 Sukhumvit 71 Rd, Watthana, Bangkok 10110',  '0891234574', 40.00, 'Delivered', '2025-11-07 19:50:00'),
(400018, '55/10 Mittraphap Rd, Pak Chong, Nakhon Ratchasima 30130', '0891234576', 30.00, 'Failed', NULL);

-- ---------------------------------------------------------------------
-- Receipt (only for non-cancelled orders)
-- Discount: 50 THB for promotion 300003; 0 otherwise (300004 gives points, not money)
-- ---------------------------------------------------------------------
INSERT INTO Receipt (Order_ID, Receipt_DateTime, Tax_ID, Tax_Address, Discount)
SELECT o.Order_ID,
       o.Order_DateTime + INTERVAL 1 MINUTE,
       NULL,
       NULL,
       CASE WHEN p.Discount_Type = 'Baht'    THEN p.Discount_Value
            WHEN p.Discount_Type = 'Percent' THEN ROUND(o.Order_Amount * p.Discount_Value / 100, 2)
            ELSE 0 END
FROM Orders o
LEFT JOIN Promotion p ON p.Promotion_ID = o.Promotion_ID
WHERE o.Order_Status <> 'Cancelled'
ORDER BY o.Order_ID;

-- a couple of customers asked for a full tax invoice
UPDATE Receipt SET Tax_ID = '0105547000001', Tax_Address = 'ABC Co., Ltd., 999 Rama 1 Rd, Pathum Wan, Bangkok 10330'
WHERE Order_ID = 400001;
UPDATE Receipt SET Tax_ID = '3100500123456', Tax_Address = '321/7 Silom Rd, Bang Rak, Bangkok 10500'
WHERE Order_ID = 400016;

-- ---------------------------------------------------------------------
-- Payment: amount = items - discount + delivery fee
-- ---------------------------------------------------------------------
INSERT INTO Payment (Order_ID, Payment_Method, Card_ID, Amount, Paid_At, Payment_Status)
SELECT o.Order_ID, m.Method, m.Card_ID,
       o.Order_Amount - r.Discount + COALESCE(d.Delivery_Fee, 0),
       r.Receipt_DateTime,
       'Success'
FROM Orders o
JOIN Receipt r       ON r.Order_ID = o.Order_ID
LEFT JOIN Delivery d ON d.Order_ID = o.Order_ID
JOIN (
    SELECT 400001 AS Order_ID, 'StarbucksCard' AS Method, 600001 AS Card_ID UNION ALL
    SELECT 400002, 'StarbucksCard', 600002 UNION ALL
    SELECT 400003, 'Cash',          NULL   UNION ALL
    SELECT 400004, 'CreditCard',    NULL   UNION ALL
    SELECT 400005, 'QR',            NULL   UNION ALL
    SELECT 400006, 'StarbucksCard', 600003 UNION ALL
    SELECT 400007, 'CreditCard',    NULL   UNION ALL
    SELECT 400008, 'StarbucksCard', 600005 UNION ALL
    SELECT 400009, 'QR',            NULL   UNION ALL
    SELECT 400010, 'CreditCard',    NULL   UNION ALL
    SELECT 400011, 'Cash',          NULL   UNION ALL
    SELECT 400012, 'StarbucksCard', 600002 UNION ALL
    SELECT 400013, 'QR',            NULL   UNION ALL
    SELECT 400016, 'CreditCard',    NULL   UNION ALL
    SELECT 400017, 'StarbucksCard', 600005
) m ON m.Order_ID = o.Order_ID
ORDER BY o.Order_ID;

-- ---------------------------------------------------------------------
-- Point_Transaction
-- 1) opening balance = the points each member had in v1
-- 2) earn 1 point per 10 THB paid; x2 when promotion is Point_Multiplier
-- ---------------------------------------------------------------------
INSERT INTO Point_Transaction (Member_ID, Order_ID, Txn_Type, Points_Change, Created_At) VALUES
(100001, NULL, 'Adjust',  50, '2025-10-31 00:00:00'),
(100002, NULL, 'Adjust', 100, '2025-10-31 00:00:00'),
(100003, NULL, 'Adjust', 150, '2025-10-31 00:00:00'),
(100004, NULL, 'Adjust', 200, '2025-10-31 00:00:00'),
(100005, NULL, 'Adjust', 250, '2025-10-31 00:00:00'),
(100006, NULL, 'Adjust', 300, '2025-10-31 00:00:00'),
(100007, NULL, 'Adjust', 350, '2025-10-31 00:00:00'),
(100008, NULL, 'Adjust', 400, '2025-10-31 00:00:00'),
(100009, NULL, 'Adjust', 450, '2025-10-31 00:00:00'),
(100010, NULL, 'Adjust', 500, '2025-10-31 00:00:00');

INSERT INTO Point_Transaction (Member_ID, Order_ID, Txn_Type, Points_Change, Created_At)
SELECT o.Member_ID, o.Order_ID, 'Earn',
       FLOOR(pay.Amount / 10) * IF(pr.Discount_Type = 'Point_Multiplier', pr.Discount_Value, 1),
       pay.Paid_At
FROM Orders o
JOIN Payment pay       ON pay.Order_ID = o.Order_ID AND pay.Payment_Status = 'Success'
LEFT JOIN Promotion pr ON pr.Promotion_ID = o.Promotion_ID
ORDER BY o.Order_ID;

-- one redemption: Sophia used 200 points for a free drink
INSERT INTO Point_Transaction (Member_ID, Order_ID, Txn_Type, Points_Change, Created_At) VALUES
(100006, 400016, 'Redeem', -200, '2025-11-06 12:30:00');

-- Member.Points = sum of history
UPDATE Member m
SET m.Points = (SELECT COALESCE(SUM(pt.Points_Change), 0)
                FROM Point_Transaction pt WHERE pt.Member_ID = m.Member_ID);
