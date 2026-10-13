-- =====================================================================
-- Coffee Chain Database — LARGE seed data (Phase 2)
-- Run AFTER: schema/schema_v2.sql  ->  seed/seed_small.sql
--
-- Generates realistic volume for performance testing (Phase 4):
--   Branch          +45   (total 50)
--   Product         +30   (total 40)
--   Promotion       +14   (total 21, spread across 2025-2026)
--   Member          +20,000
--   Member_Address  +20,000 (one default address per new member)
--   Starbucks_Card  ~7,000  (about 35% of new members)
--   Orders          +200,000  (2025-01-01 .. 2026-09-30)
--   Order_Item      ~360,000
--   + matching InStorePickup / OrderToTable / Delivery / Receipt / Payment / Point_Transaction
--
-- Realism rules built in:
--   * Older members order more (loyal customers); a member never orders before registering
--   * Order volume grows over time (more members registered later)
--   * Peak hours: 07-09, 12-13, 17-18
--   * Popular products sell far more than others (Americano/Latte top, merch rare)
--   * Drive Thru branches never get Order-to-Table orders; Delivery never paid by Cash
--   * Order_Amount computed by triggers; Payment = items - discount + delivery fee
--   * Points earned = 1 per 10 THB paid (x2 during Point_Multiplier promotions)
--
-- Pure SQL, no extra tools needed. Randomness comes from MD5 hashes of row numbers,
-- so every run gives exactly the same data. (Seeded RAND(n) was avoided: nearby seeds
-- in MySQL produce correlated number streams.)
-- Takes roughly 1-3 minutes. In Workbench, first set:
--   Preferences > SQL Editor > DBMS connection read timeout = 600
-- =====================================================================
USE coffee_chain_db;
-- Workbench enables safe-update mode by default, which blocks the bulk UPDATEs below
SET SQL_SAFE_UPDATES = 0;
SET SQL_BIG_SELECTS = 1;

-- ---------------------------------------------------------------------
-- 0. Helper: number table 1..1,000,000
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_digit, tmp_seq;
CREATE TABLE tmp_digit (d TINYINT PRIMARY KEY);
INSERT INTO tmp_digit VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);

CREATE TABLE tmp_seq (n INT PRIMARY KEY);
INSERT INTO tmp_seq (n)
SELECT 1 + a.d + 10*b.d + 100*c.d + 1000*d.d + 10000*e.d + 100000*f.d
FROM tmp_digit a, tmp_digit b, tmp_digit c, tmp_digit d, tmp_digit e, tmp_digit f;

-- ---------------------------------------------------------------------
-- 1. Branches (+45)
-- ---------------------------------------------------------------------
INSERT INTO Branch (Branch_ID, Branch_Name, Location, Open_Time, Close_Time, Contact_Number, Store_Type, Branch_Manager, Branch_Status) VALUES
(1006, 'Starbucks EmQuartier',            'EmQuartier, Bangkok',              '08:00', '22:00', '021234571', 'Coffee House', 'Krit F.',    'Open'),
(1007, 'Starbucks Central Ladprao',       'Central Ladprao, Bangkok',         '08:00', '22:00', '021234572', 'Coffee House', 'Mali G.',    'Open'),
(1008, 'Starbucks Silom Complex',         'Silom Complex, Bangkok',           '07:00', '21:00', '021234573', 'Coffee House', 'Tanawat H.', 'Open'),
(1009, 'Starbucks Asok',                  'Terminal 21, Bangkok',             '07:00', '22:00', '021234574', 'Coffee House', 'Pim I.',     'Open'),
(1010, 'Starbucks Ari',                   'Phahonyothin Soi 7, Bangkok',      '07:00', '21:00', '021234575', 'Coffee House', 'Nok J.',     'Open'),
(1011, 'Starbucks Thonglor',              'Thonglor Soi 13, Bangkok',         '07:00', '22:00', '021234576', 'Coffee House', 'Arthit K.',  'Open'),
(1012, 'Starbucks Samyan Mitrtown',       'Samyan Mitrtown, Bangkok',         '00:00', '23:59', '021234577', 'Coffee House', 'Fon L.',     'Open'),
(1013, 'Starbucks Mega Bangna',           'Mega Bangna, Samut Prakan',        '10:00', '22:00', '021234578', 'Coffee House', 'Boy M.',     'Open'),
(1014, 'Starbucks Future Park Rangsit',   'Future Park, Pathum Thani',        '10:00', '22:00', '021234579', 'Coffee House', 'Aom N.',     'Open'),
(1015, 'Starbucks The Mall Bangkapi',     'The Mall Bangkapi, Bangkok',       '10:00', '22:00', '021234580', 'Coffee House', 'Ton O.',     'Open'),
(1016, 'Starbucks Central Rama 9',        'Central Rama 9, Bangkok',          '10:00', '22:00', '021234581', 'Coffee House', 'Gift P.',    'Open'),
(1017, 'Starbucks Seacon Square',         'Seacon Square, Bangkok',           '10:00', '22:00', '021234582', 'Coffee House', 'Bank Q.',    'Open'),
(1018, 'Starbucks Mahidol Salaya',        'Mahidol University, Nakhon Pathom','07:00', '20:00', '021234583', 'Coffee House', 'Mint R.',    'Open'),
(1019, 'Starbucks Suvarnabhumi Airport',  'Suvarnabhumi Airport, Samut Prakan','00:00','23:59', '021234584', 'Coffee House', 'Jay S.',     'Open'),
(1020, 'Starbucks Don Mueang Airport',    'Don Mueang Airport, Bangkok',      '00:00', '23:59', '021234585', 'Coffee House', 'Ploy T.',    'Open'),
(1021, 'Starbucks Drive Thru Ratchaphruek','Ratchaphruek Rd, Bangkok',        '06:00', '22:00', '021234586', 'Drive Thru',   'Nat U.',     'Open'),
(1022, 'Starbucks Drive Thru Bangna-Trad','Bangna-Trad Km 7, Samut Prakan',   '06:00', '22:00', '021234587', 'Drive Thru',   'Earn V.',    'Open'),
(1023, 'Starbucks Drive Thru Kaset-Nawamin','Kaset-Nawamin Rd, Bangkok',      '06:00', '22:00', '021234588', 'Drive Thru',   'Golf W.',    'Open'),
(1024, 'Starbucks Drive Thru Rama 5',     'Rama 5 Rd, Nonthaburi',            '06:00', '22:00', '021234589', 'Drive Thru',   'View X.',    'Open'),
(1025, 'Starbucks Drive Thru Chaengwattana','Chaengwattana Rd, Nonthaburi',   '06:00', '22:00', '021234590', 'Drive Thru',   'Oat Y.',     'Open'),
(1026, 'Starbucks Central Westgate',      'Central Westgate, Nonthaburi',     '10:00', '22:00', '021234591', 'Coffee House', 'Beam Z.',    'Open'),
(1027, 'Starbucks Fashion Island',        'Fashion Island, Bangkok',          '10:00', '22:00', '021234592', 'Coffee House', 'Ice A.',     'Open'),
(1028, 'Starbucks Siam Square One',       'Siam Square One, Bangkok',         '08:00', '22:00', '021234593', 'Coffee House', 'Pang B.',    'Open'),
(1029, 'Starbucks Chamchuri Square',      'Chamchuri Square, Bangkok',        '07:00', '21:00', '021234594', 'Coffee House', 'Tee C.',     'Open'),
(1030, 'Starbucks Sathorn Square',        'Sathorn Square, Bangkok',          '07:00', '20:00', '021234595', 'Coffee House', 'Fah D.',     'Open'),
(1031, 'Starbucks Central Chiang Mai',    'Central Festival, Chiang Mai',     '10:00', '22:00', '053123457', 'Coffee House', 'Nan E.',     'Open'),
(1032, 'Starbucks Old City Chiang Mai',   'Tha Phae Gate, Chiang Mai',        '07:00', '21:00', '053123458', 'Coffee House', 'Win F.',     'Open'),
(1033, 'Starbucks Central Phuket',        'Central Phuket, Phuket',           '10:00', '22:00', '076123456', 'Coffee House', 'Kai G.',     'Open'),
(1034, 'Starbucks Patong Beach',          'Patong Beach, Phuket',             '08:00', '23:00', '076123457', 'Coffee House', 'Toey H.',    'Open'),
(1035, 'Starbucks Pattaya Beach Road',    'Beach Rd, Chonburi',               '08:00', '23:00', '038123456', 'Coffee House', 'Fluke I.',   'Open'),
(1036, 'Starbucks Terminal 21 Pattaya',   'Terminal 21 Pattaya, Chonburi',    '10:00', '22:00', '038123457', 'Coffee House', 'Ying J.',    'Open'),
(1037, 'Starbucks Central Khon Kaen',     'Central Khon Kaen, Khon Kaen',     '10:00', '22:00', '043123456', 'Coffee House', 'Pond K.',    'Open'),
(1038, 'Starbucks Terminal 21 Korat',     'Terminal 21 Korat, Nakhon Ratchasima','10:00','22:00','044123456', 'Coffee House', 'Bow L.',     'Open'),
(1039, 'Starbucks Central Hat Yai',       'Central Festival, Songkhla',       '10:00', '22:00', '074123456', 'Coffee House', 'Film M.',    'Open'),
(1040, 'Starbucks Hua Hin Market Village','Market Village, Prachuap Khiri Khan','10:00','22:00','032123456', 'Coffee House', 'Jom N.',     'Open'),
(1041, 'Starbucks Central Udon',          'Central Udon, Udon Thani',         '10:00', '22:00', '042123456', 'Coffee House', 'Kwan O.',    'Open'),
(1042, 'Starbucks Ayutthaya Park',        'Ayutthaya Park, Ayutthaya',        '10:00', '21:00', '035123456', 'Coffee House', 'Mew P.',     'Open'),
(1043, 'Starbucks Drive Thru Chiang Mai', 'Superhighway Rd, Chiang Mai',      '06:30', '21:30', '053123459', 'Drive Thru',   'Art Q.',     'Open'),
(1044, 'Starbucks Drive Thru Korat',      'Mittraphap Rd, Nakhon Ratchasima', '06:30', '21:30', '044123457', 'Drive Thru',   'Joy R.',     'Open'),
(1045, 'Starbucks Drive Thru Hua Hin',    'Phetkasem Rd, Prachuap Khiri Khan','06:30', '21:30', '032123457', 'Drive Thru',   'Max S.',     'Open'),
(1046, 'Starbucks Central Rayong',        'Central Rayong, Rayong',           '10:00', '22:00', '038123458', 'Coffee House', 'Nook T.',    'Open'),
(1047, 'Starbucks Central Pinklao',       'Central Pinklao, Bangkok',         '10:00', '22:00', '021234596', 'Coffee House', 'Prae U.',    'Open'),
(1048, 'Starbucks Gaysorn Village',       'Gaysorn Village, Bangkok',         '08:00', '22:00', '021234597', 'Coffee House', 'Tar V.',     'Open'),
(1049, 'Starbucks K Village',             'K Village, Bangkok',               '08:00', '22:00', '021234598', 'Coffee House', 'Ohm W.',     'Closed'),
(1050, 'Starbucks Rajamangala Stadium',   'Rajamangala Stadium, Bangkok',     '09:00', '20:00', '021234599', 'Coffee House', 'Few X.',     'Renovation');

-- ---------------------------------------------------------------------
-- 2. Products (+30)
-- ---------------------------------------------------------------------
INSERT INTO Product (Product_ID, Product_Name, Product_Description, Type_Product, Base_Price, Is_Active, Is_Seasonal) VALUES
(200011, 'Espresso',                    'Single shot espresso',                     'Beverage',  85.00, 1, 0),
(200012, 'Cappuccino',                  'Espresso with foamed milk',                'Beverage', 125.00, 1, 0),
(200013, 'Flat White',                  'Ristretto with velvety milk',              'Beverage', 135.00, 1, 0),
(200014, 'Caffè Mocha',                 'Espresso, chocolate and steamed milk',     'Beverage', 145.00, 1, 0),
(200015, 'White Chocolate Mocha',       'Espresso with white chocolate sauce',      'Beverage', 150.00, 1, 0),
(200016, 'Cold Brew',                   'Slow-steeped cold coffee',                 'Beverage', 130.00, 1, 0),
(200017, 'Nitro Cold Brew',             'Cold brew infused with nitrogen',          'Beverage', 145.00, 1, 0),
(200018, 'Iced Shaken Espresso',        'Espresso shaken with ice and syrup',       'Beverage', 140.00, 1, 0),
(200019, 'Java Chip Frappuccino',       'Blended coffee with chocolate chips',      'Beverage', 165.00, 1, 0),
(200020, 'Caramel Frappuccino',         'Blended coffee with caramel',              'Beverage', 160.00, 1, 0),
(200021, 'Mocha Frappuccino',           'Blended coffee with mocha sauce',          'Beverage', 160.00, 1, 0),
(200022, 'Chai Tea Latte',              'Spiced black tea with steamed milk',       'Beverage', 135.00, 1, 0),
(200023, 'Matcha Latte',                'Japanese matcha with steamed milk',        'Beverage', 140.00, 1, 0),
(200024, 'Iced Black Tea',              'Shaken black tea over ice',                'Beverage',  95.00, 1, 0),
(200025, 'Signature Hot Chocolate',     'Rich chocolate with steamed milk',         'Beverage', 120.00, 1, 0),
(200026, 'Strawberry Açaí Refresher',   'Fruit refresher with strawberry pieces',   'Beverage', 130.00, 1, 0),
(200027, 'Peach Green Tea Lemonade',    'Green tea with peach and lemonade',        'Beverage', 125.00, 1, 0),
(200028, 'Honey Citrus Mint Tea',       'Mint and citrus tea with honey',           'Beverage', 120.00, 1, 0),
(200029, 'Butter Croissant',            'Classic French butter croissant',          'Food',      70.00, 1, 0),
(200030, 'Blueberry Muffin',            'Muffin with blueberries',                  'Food',      85.00, 1, 0),
(200031, 'Banana Walnut Cake',          'Moist banana cake with walnuts',           'Food',      90.00, 1, 0),
(200032, 'Tuna Sandwich',               'Tuna salad on whole wheat bread',          'Food',     125.00, 1, 0),
(200033, 'Chicken Pesto Panini',        'Grilled chicken with basil pesto',         'Food',     145.00, 1, 0),
(200034, 'Cinnamon Roll',               'Soft roll with cinnamon glaze',            'Food',      85.00, 1, 0),
(200035, 'Fudge Brownie',               'Dense chocolate brownie',                  'Food',      80.00, 1, 0),
(200036, 'Chocolate Cake',              'Slice of layered chocolate cake',          'Food',     135.00, 1, 0),
(200037, 'Stainless Tumbler 16oz',      'Double-wall stainless tumbler',            'Merch',    790.00, 1, 0),
(200038, 'House Blend Beans 250g',      'Whole bean coffee, medium roast',          'Merch',    450.00, 1, 0),
(200039, 'Insulated Bottle 500ml',      'Vacuum insulated bottle',                  'Merch',    950.00, 1, 0),
(200040, 'Canvas Tote Bag',             'Reusable canvas tote',                     'Merch',    590.00, 1, 0);

-- popularity ranking used to pick products (rank 1 = best seller)
DROP TABLE IF EXISTS tmp_product_rank;
CREATE TABLE tmp_product_rank (rnk INT PRIMARY KEY, Product_ID INT NOT NULL);
INSERT INTO tmp_product_rank VALUES
( 1,200002),( 2,200001),( 3,200003),( 4,200018),( 5,200023),( 6,200016),( 7,200012),( 8,200020),
( 9,200014),(10,200019),(11,200029),(12,200004),(13,200027),(14,200022),(15,200024),(16,200013),
(17,200026),(18,200015),(19,200007),(20,200021),(21,200005),(22,200030),(23,200032),(24,200017),
(25,200006),(26,200025),(27,200034),(28,200035),(29,200033),(30,200028),(31,200031),(32,200036),
(33,200011),(34,200010),(35,200008),(36,200038),(37,200037),(38,200009),(39,200040),(40,200039);

-- ---------------------------------------------------------------------
-- 3. Promotions (+14) so 2025-2026 orders have promotions to use
-- ---------------------------------------------------------------------
INSERT INTO Promotion (Promotion_ID, Promotion_Name, Description, Discount_Type, Discount_Value, Start_Date, End_Date) VALUES
(300008, 'New Year Latte 20% Off',      '20% off all lattes',                   'Percent',          20.00, '2025-01-15', '2025-02-15'),
(300009, 'Valentine Treat 50 Baht',     '50 THB off orders for two',            'Baht',             50.00, '2025-02-10', '2025-02-14'),
(300010, 'Summer Frappuccino 15% Off',  '15% off all Frappuccino',              'Percent',          15.00, '2025-03-01', '2025-03-31'),
(300011, 'Songkran Double Stars',       'Double points during Songkran',        'Point_Multiplier',  2.00, '2025-04-10', '2025-04-16'),
(300012, 'Rainy Day 30 Baht',           '30 THB off when it rains',             'Baht',             30.00, '2025-05-01', '2025-05-31'),
(300013, 'Mid-Year 10% Off',            '10% off every order',                  'Percent',          10.00, '2025-06-01', '2025-06-30'),
(300014, 'Cold Brew Month 20% Off',     '20% off cold brew',                    'Percent',          20.00, '2025-07-01', '2025-07-31'),
(300015, 'Mother''s Day 40 Baht',       '40 THB off for Mother''s Day',         'Baht',             40.00, '2025-08-01', '2025-08-15'),
(300016, 'Back to School 15% Off',      '15% off for students',                 'Percent',          15.00, '2025-09-01', '2025-09-30'),
(300017, 'New Year 2026 Double Stars',  'Double points in January',             'Point_Multiplier',  2.00, '2026-01-01', '2026-01-31'),
(300018, 'Lunar New Year 15% Off',      '15% off during Lunar New Year',        'Percent',          15.00, '2026-02-01', '2026-02-28'),
(300019, 'Summer 2026 20 Baht',         '20 THB off any iced drink',            'Baht',             20.00, '2026-03-01', '2026-04-30'),
(300020, 'Songkran 2026 Double Stars',  'Double points during Songkran',        'Point_Multiplier',  2.00, '2026-04-10', '2026-04-17'),
(300021, 'Matcha Month 10% Off',        '10% off matcha drinks',                'Percent',          10.00, '2026-05-01', '2026-05-31');

-- ---------------------------------------------------------------------
-- 4. Members (+20,000)
--    Member k (0..19999) gets ID 100011+k; registration date rises with k
--    (2022-01-01 .. 2026-08-31), so lower IDs = older, more loyal members.
-- ---------------------------------------------------------------------
INSERT INTO Member (Member_ID, Member_Name, Email, Phone_Number, Date_of_Birth, Registration_Date, Member_Level, Member_Status)
SELECT
    100010 + s.n,
    CONCAT(fn, ' ', ln),
    CONCAT(LOWER(REPLACE(fn,' ','')), '.', LOWER(REPLACE(ln,' ','')), s.n, '@example.com'),
    CONCAT('08', LPAD(20000000 + s.n, 8, '0')),
    DATE_ADD('1965-01-01', INTERVAL FLOOR(r_dob * 15340) DAY),            -- 1965 .. 2006
    DATE_ADD('2022-01-01', INTERVAL FLOOR((s.n - 1) / 20000 * 1704) DAY), -- 2022-01-01 .. 2026-08-31
    'Green',
    CASE WHEN r_status < 0.92 THEN 'Active' WHEN r_status < 0.98 THEN 'Inactive' ELSE 'Banned' END
FROM (
    SELECT n,
           ELT(1 + FLOOR((CONV(LEFT(MD5(CONCAT('fn-', n)), 8), 16, 10) / 4294967296) * 30),
               'Somchai','Suda','Anan','Ploy','Napat','Krit','Mali','Tanawat','Pim','Arthit',
               'Kanya','Wichai','Nicha','Thanakorn','Siriporn','Chaiwat','Pornthip','Kittisak','Waraporn','Nattapong',
               'James','Emily','Daniel','Sarah','Kenji','Yuki','Minh','Lina','Arjun','Mei') AS fn,
           ELT(1 + FLOOR((CONV(LEFT(MD5(CONCAT('ln-', n)), 8), 16, 10) / 4294967296) * 30),
               'Saetang','Wongsa','Srisuk','Chaiyaporn','Rattanakul','Boonmee','Kaewkla','Thongdee','Phromma','Suwan',
               'Jaidee','Siripong','Kongsuk','Nakorn','Petcharat','Yodkaew','Manee','Charoen','Intharat','Sombat',
               'Smith','Brown','Tanaka','Sato','Nguyen','Kim','Chen','Patel','Wilson','Lee') AS ln,
           (CONV(LEFT(MD5(CONCAT('dob-', n)), 8), 16, 10) / 4294967296) AS r_dob,
           (CONV(LEFT(MD5(CONCAT('st-', n)), 8), 16, 10) / 4294967296) AS r_status
    FROM tmp_seq WHERE n <= 20000
) s;

-- one default address per new member
INSERT INTO Member_Address (Member_ID, Label, Address_Line, District, Province, Postal_Code, Is_Default)
SELECT m.Member_ID, 'Home',
       CONCAT(1 + (m.Member_ID * 37) % 400, '/', 1 + (m.Member_ID * 11) % 30, ' ',
              ELT(1 + (m.Member_ID * 7) % 10, 'Sukhumvit Rd','Phahonyothin Rd','Rama 4 Rd','Ratchadaphisek Rd','Ladprao Rd',
                                             'Charoen Krung Rd','Ramkhamhaeng Rd','Srinakarin Rd','Ngamwongwan Rd','Petchkasem Rd')),
       ELT(1 + d.k, 'Watthana','Chatuchak','Bang Kapi','Huai Khwang','Pathum Wan','Bang Rak','Sathon','Phaya Thai',
                    'Mueang Nonthaburi','Bang Phli','Mueang Chiang Mai','Kathu','Bang Lamung','Mueang Khon Kaen','Hat Yai'),
       ELT(1 + d.k, 'Bangkok','Bangkok','Bangkok','Bangkok','Bangkok','Bangkok','Bangkok','Bangkok',
                    'Nonthaburi','Samut Prakan','Chiang Mai','Phuket','Chonburi','Khon Kaen','Songkhla'),
       ELT(1 + d.k, '10110','10900','10240','10310','10330','10500','10120','10400',
                    '11000','10540','50000','83120','20150','40000','90110'),
       1
FROM Member m
JOIN (SELECT Member_ID, FLOOR(POW((CONV(LEFT(MD5(CONCAT('addr-', Member_ID)), 8), 16, 10) / 4294967296), 1.6) * 15) AS k FROM Member WHERE Member_ID > 100010) d
  ON d.Member_ID = m.Member_ID;

-- Starbucks cards for ~35% of new members
INSERT INTO Starbucks_Card (Card_Number, Member_ID, Balance, Card_Status, Issued_Date)
SELECT CONCAT('6012', LPAD(Member_ID, 12, '0')),
       Member_ID,
       ROUND((CONV(LEFT(MD5(CONCAT('bal-', Member_ID)), 8), 16, 10) / 4294967296) * 2000, 2),
       CASE WHEN Member_Status = 'Banned' THEN 'Blocked' ELSE 'Active' END,
       DATE_ADD(Registration_Date, INTERVAL 3 DAY)
FROM Member
WHERE Member_ID > 100010 AND Member_ID % 100 < 35;

-- ---------------------------------------------------------------------
-- 5. Orders (+200,000)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_orders;
CREATE TABLE tmp_orders (
    n INT PRIMARY KEY,
    k INT, r_day DOUBLE, r_hour DOUBLE, r_min DOUBLE, r_branch DOUBLE, r_type DOUBLE, r_status DOUBLE
);
INSERT INTO tmp_orders
SELECT n,
       FLOOR(POW((CONV(LEFT(MD5(CONCAT('mem-', n)), 8), 16, 10) / 4294967296), 1.5) * 20000),   -- member index, skewed toward older members
       (CONV(LEFT(MD5(CONCAT('day-', n)), 8), 16, 10) / 4294967296), (CONV(LEFT(MD5(CONCAT('hour-', n)), 8), 16, 10) / 4294967296), (CONV(LEFT(MD5(CONCAT('min-', n)), 8), 16, 10) / 4294967296), (CONV(LEFT(MD5(CONCAT('br-', n)), 8), 16, 10) / 4294967296), (CONV(LEFT(MD5(CONCAT('type-', n)), 8), 16, 10) / 4294967296), (CONV(LEFT(MD5(CONCAT('stat-', n)), 8), 16, 10) / 4294967296)
FROM tmp_seq WHERE n <= 200000;

INSERT INTO Orders (Order_ID, Member_ID, Branch_ID, Promotion_ID, Order_Type, Order_Status, Order_DateTime)
SELECT
    400018 + t.n,
    100011 + t.k,
    b.Branch_ID,
    NULL,
    CASE
        WHEN b.Store_Type = 'Drive Thru' THEN IF(t.r_type < 0.8, 'InStorePickup', 'Delivery')
        WHEN t.r_type < 0.5 THEN 'InStorePickup'
        WHEN t.r_type < 0.8 THEN 'OrderToTable'
        ELSE 'Delivery'
    END,
    'Completed',   -- adjusted below
    TIMESTAMP(
        DATE_ADD(t.start_date, INTERVAL FLOOR(t.r_day * (DATEDIFF('2026-09-30', t.start_date) + 1)) DAY),
        -- peak-hour pattern, clamped to the branch's opening hours
        MAKETIME(LEAST(GREATEST(0 + ELT(1 + FLOOR(t.r_hour * 24), 7,7,8,8,8,8,9,9,10,10,11,12,12,12,13,13,14,15,16,17,17,18,19,20),
                                HOUR(b.Open_Time)),
                       HOUR(b.Close_Time) - 1),
                 FLOOR(t.r_min * 60), 0)
    )
FROM (
    SELECT o.*,
           GREATEST(DATE_ADD('2022-01-01', INTERVAL FLOOR(o.k / 20000 * 1704) DAY), DATE('2025-01-01')) AS start_date,
           1001 + FLOOR(POW(o.r_branch, 1.4) * 50) AS branch_id
    FROM tmp_orders o
) t
JOIN Branch b ON b.Branch_ID = t.branch_id;

-- status: 5% cancelled, recent ones still 'Paid', the rest 'Completed'
UPDATE Orders o
JOIN tmp_orders t ON o.Order_ID = 400018 + t.n
SET o.Order_Status = CASE
        WHEN t.r_status < 0.05 THEN 'Cancelled'
        WHEN o.Order_DateTime >= '2026-09-29' THEN 'Paid'
        ELSE 'Completed'
    END;

-- 18% of orders placed while a promotion is running use it (~5% of all orders,
-- since promotions don't cover every day)
UPDATE Orders o
JOIN Promotion p ON DATE(o.Order_DateTime) BETWEEN p.Start_Date AND p.End_Date
SET o.Promotion_ID = p.Promotion_ID
WHERE o.Order_ID > 400018
  AND (o.Order_ID * 2654435761) % 1000 < 180;

-- ---------------------------------------------------------------------
-- 6. Order items (1-4 lines per order; triggers fill Order_Amount)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_items;
CREATE TABLE tmp_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    Order_ID INT, r_prod DOUBLE, r_size DOUBLE, r_qty DOUBLE, r_cust DOUBLE
);
INSERT INTO tmp_items (Order_ID, r_prod, r_size, r_qty, r_cust)
SELECT o.Order_ID, (CONV(LEFT(MD5(CONCAT('prod-', o.Order_ID, '-', s.n)), 8), 16, 10) / 4294967296), (CONV(LEFT(MD5(CONCAT('size-', o.Order_ID, '-', s.n)), 8), 16, 10) / 4294967296), (CONV(LEFT(MD5(CONCAT('qty-', o.Order_ID, '-', s.n)), 8), 16, 10) / 4294967296), (CONV(LEFT(MD5(CONCAT('cust-', o.Order_ID, '-', s.n)), 8), 16, 10) / 4294967296)
FROM Orders o
JOIN tmp_seq s
  ON s.n <= 1 + ((o.Order_ID * 7919) % 100 >= 45) + ((o.Order_ID * 7919) % 100 >= 80) + ((o.Order_ID * 7919) % 100 >= 95)
WHERE o.Order_ID > 400018
ORDER BY o.Order_ID, s.n;

INSERT INTO Order_Item (Order_ID, Product_ID, Size, Customize, Quantity, Unit_Price)
SELECT x.Order_ID, p.Product_ID, x.Size, x.Customize, x.Quantity,
       p.Base_Price + CASE x.Size WHEN 'Short' THEN -10 WHEN 'Grande' THEN 15 WHEN 'Venti' THEN 30 ELSE 0 END
FROM (
    SELECT i.Order_ID, pr.Product_ID, pp.Type_Product,
           CASE WHEN pp.Type_Product <> 'Beverage' THEN NULL
                WHEN i.r_size < 0.05 THEN 'Short'
                WHEN i.r_size < 0.40 THEN 'Tall'
                WHEN i.r_size < 0.85 THEN 'Grande'
                ELSE 'Venti' END AS Size,
           CASE WHEN pp.Type_Product = 'Beverage' AND i.r_cust < 0.40
                THEN ELT(1 + FLOOR(i.r_cust / 0.40 * 7), 'Less ice','Oat milk','Extra shot','Less sweet','Non-fat milk','Soy milk','No whip')
                ELSE NULL END AS Customize,
           CASE WHEN pp.Type_Product = 'Merch' THEN 1
                WHEN i.r_qty < 0.80 THEN 1
                WHEN i.r_qty < 0.95 THEN 2
                ELSE 3 END AS Quantity,
           i.id
    FROM tmp_items i
    JOIN tmp_product_rank pr ON pr.rnk = 1 + FLOOR(POW(i.r_prod, 1.8) * 40)
    JOIN Product pp          ON pp.Product_ID = pr.Product_ID
) x
JOIN Product p ON p.Product_ID = x.Product_ID
ORDER BY x.id;

-- ---------------------------------------------------------------------
-- 7. Order subtypes
-- ---------------------------------------------------------------------
INSERT INTO InStorePickup (Order_ID, Pickup_Time, Pickup_Status)
SELECT Order_ID,
       IF(Order_Status = 'Completed', Order_DateTime + INTERVAL (5 + Order_ID % 16) MINUTE, NULL),
       CASE WHEN Order_Status <> 'Completed' THEN 'Waiting'
            WHEN Order_ID % 10 = 0          THEN 'Late'
            ELSE 'Picked' END
FROM Orders
WHERE Order_ID > 400018 AND Order_Type = 'InStorePickup';

INSERT INTO OrderToTable (Order_ID, Table_Number)
SELECT Order_ID, 1 + (Order_ID * 13) % 20
FROM Orders
WHERE Order_ID > 400018 AND Order_Type = 'OrderToTable';

INSERT INTO Delivery (Order_ID, Delivery_Address, Contact_Phone, Delivery_Fee, Delivery_Status, Delivered_At)
SELECT o.Order_ID,
       CONCAT(a.Address_Line, ', ', a.District, ', ', a.Province, ' ', a.Postal_Code),
       m.Phone_Number,
       IF(o.Order_Amount >= 500, 0, 30),
       CASE o.Order_Status WHEN 'Completed' THEN 'Delivered' WHEN 'Paid' THEN 'Preparing' ELSE 'Failed' END,
       IF(o.Order_Status = 'Completed', o.Order_DateTime + INTERVAL (25 + o.Order_ID % 36) MINUTE, NULL)
FROM Orders o
JOIN Member m          ON m.Member_ID = o.Member_ID
JOIN Member_Address a  ON a.Member_ID = o.Member_ID AND a.Is_Default = 1
WHERE o.Order_ID > 400018 AND o.Order_Type = 'Delivery';

-- ---------------------------------------------------------------------
-- 8. Receipts (not for cancelled orders)
-- ---------------------------------------------------------------------
INSERT INTO Receipt (Order_ID, Receipt_DateTime, Tax_ID, Tax_Address, Discount)
SELECT o.Order_ID,
       o.Order_DateTime + INTERVAL 1 MINUTE,
       NULL, NULL,
       CASE WHEN p.Discount_Type = 'Baht'    THEN LEAST(p.Discount_Value, o.Order_Amount)
            WHEN p.Discount_Type = 'Percent' THEN ROUND(o.Order_Amount * p.Discount_Value / 100, 2)
            ELSE 0 END
FROM Orders o
LEFT JOIN Promotion p ON p.Promotion_ID = o.Promotion_ID
WHERE o.Order_ID > 400018 AND o.Order_Status <> 'Cancelled'
ORDER BY o.Order_ID;

-- ---------------------------------------------------------------------
-- 9. Payments: card holders pay by Starbucks Card ~55% of the time;
--    delivery orders are never cash
-- ---------------------------------------------------------------------
INSERT INTO Payment (Order_ID, Payment_Method, Card_ID, Amount, Paid_At, Payment_Status)
SELECT x.Order_ID,
       x.Method,
       IF(x.Method = 'StarbucksCard', x.Card_ID, NULL),
       x.Amount,
       x.Paid_At,
       'Success'
FROM (
    SELECT o.Order_ID,
           c.Card_ID,
           o.Order_Amount - r.Discount + COALESCE(d.Delivery_Fee, 0) AS Amount,
           r.Receipt_DateTime AS Paid_At,
           CASE
               WHEN c.Card_ID IS NOT NULL AND (o.Order_ID * 31) % 100 < 55 THEN 'StarbucksCard'
               WHEN o.Order_Type = 'Delivery' THEN IF((o.Order_ID * 17) % 100 < 50, 'CreditCard', 'QR')
               ELSE ELT(1 + (o.Order_ID * 17) % 3, 'CreditCard', 'QR', 'Cash')
           END AS Method
    FROM Orders o
    JOIN Receipt r         ON r.Order_ID = o.Order_ID
    LEFT JOIN Delivery d   ON d.Order_ID = o.Order_ID
    LEFT JOIN Starbucks_Card c ON c.Member_ID = o.Member_ID AND c.Card_Status = 'Active'
    WHERE o.Order_ID > 400018
) x
WHERE x.Amount > 0
ORDER BY x.Order_ID;

-- ---------------------------------------------------------------------
-- 10. Points: 1 point per 10 THB paid, x2 with Point_Multiplier promotions
-- ---------------------------------------------------------------------
INSERT INTO Point_Transaction (Member_ID, Order_ID, Txn_Type, Points_Change, Created_At)
SELECT o.Member_ID, o.Order_ID, 'Earn',
       FLOOR(pay.Amount / 10) * IF(pr.Discount_Type = 'Point_Multiplier', pr.Discount_Value, 1),
       pay.Paid_At
FROM Orders o
JOIN Payment pay       ON pay.Order_ID = o.Order_ID AND pay.Payment_Status = 'Success'
LEFT JOIN Promotion pr ON pr.Promotion_ID = o.Promotion_ID
WHERE o.Order_ID > 400018
  AND FLOOR(pay.Amount / 10) > 0
ORDER BY o.Order_ID;

-- Member.Points = sum of history; Gold level at 500+ points
UPDATE Member m
LEFT JOIN (SELECT Member_ID, SUM(Points_Change) AS pts FROM Point_Transaction GROUP BY Member_ID) t
       ON t.Member_ID = m.Member_ID
SET m.Points = COALESCE(t.pts, 0),
    m.Member_Level = IF(COALESCE(t.pts, 0) >= 500, 'Gold', 'Green');

-- ---------------------------------------------------------------------
-- 11. Clean up helper tables and refresh optimizer statistics
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_items, tmp_orders, tmp_product_rank, tmp_seq, tmp_digit;

ANALYZE TABLE Member, Member_Address, Branch, Product, Promotion, Starbucks_Card,
              Orders, Order_Item, InStorePickup, OrderToTable, Delivery, Receipt, Payment, Point_Transaction;
