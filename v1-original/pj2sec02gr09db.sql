DROP DATABASE IF EXISTS pj2sec02gr09db;
CREATE DATABASE pj2sec02gr09db;
USE pj2sec02gr09db;

-- MASTER TABLES

-- Table: Member
CREATE TABLE Member (
    Member_ID INT NOT NULL,
    Member_Name VARCHAR(100) NOT NULL,
    E_mail VARCHAR(100) NULL,
    Phone_Number VARCHAR(15) NULL,
    Date_of_Birth DATE NULL,
    Points INT NOT NULL DEFAULT 0,
    Registration_Date DATE NOT NULL,
    Member_Level VARCHAR(20) NOT NULL,
    Member_Status VARCHAR(20) NOT NULL,
    CONSTRAINT PK_Member PRIMARY KEY (Member_ID),
    CONSTRAINT CHK_Member_Level CHECK (Member_Level IN ('Green','Gold')),
    CONSTRAINT CHK_Member_Status CHECK (Member_Status IN ('Active','Inactive','Banned')),
    CONSTRAINT CHK_Member_Points CHECK (Points >= 0)
);

-- Table: Member_Address
CREATE TABLE Member_Address (
    Member_ID INT NOT NULL,
    Member_Address VARCHAR(200) NOT NULL,
    CONSTRAINT PK_Member_Address PRIMARY KEY (Member_ID, Member_Address),
    CONSTRAINT FK_Member_Address_Member FOREIGN KEY (Member_ID)
        REFERENCES Member(Member_ID)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- Table: Product
CREATE TABLE Product (
    Product_ID INT NOT NULL,
    Product_Name VARCHAR(100) NOT NULL,
    Product_Description VARCHAR(255) NULL,
    Is_Active TINYINT(1) NOT NULL DEFAULT 1,
    Is_Seasonal TINYINT(1) NOT NULL DEFAULT 0,
    Type_Product VARCHAR(30) NULL,
    CONSTRAINT PK_Product PRIMARY KEY (Product_ID),
    CONSTRAINT CHK_Product_Is_Active CHECK (Is_Active IN (0,1)),
    CONSTRAINT CHK_Product_Is_Seasonal CHECK (Is_Seasonal IN (0,1)),
    CONSTRAINT CHK_Type_Product CHECK (Type_Product IN ('Beverage','Food','Merch'))
);

-- Table: Branch
CREATE TABLE Branch (
    Branch_ID INT NOT NULL,
    Branch_Name VARCHAR(100) NOT NULL,
    Location VARCHAR(200) NOT NULL,
    Opening_Hours VARCHAR(50) NULL,
    Contact_Number VARCHAR(15) NULL,
    Store_Type VARCHAR(30) NULL,
    Branch_Manager VARCHAR(100) NULL,
    Branch_Status VARCHAR(20) NULL,
    CONSTRAINT PK_Branch PRIMARY KEY (Branch_ID),
    CONSTRAINT CHK_Store_Type CHECK (Store_Type IN ('Drive Thru','Coffee House')),
    CONSTRAINT CHK_Branch_Status CHECK (Branch_Status IN ('Open','Closed','Renovation'))
);

-- Table: Promotion
CREATE TABLE Promotion (
    Promotion_ID INT NOT NULL,
    Promotion_Name VARCHAR(100) NOT NULL,
    Start_Date DATE NULL,
    End_Date DATE NULL,
    Description VARCHAR(255) NULL,
    Discount_Type VARCHAR(20) NULL,
    Promotion_Status VARCHAR(20) NULL,
    CONSTRAINT PK_Promotion PRIMARY KEY (Promotion_ID),
    CONSTRAINT CHK_Discount_Type CHECK (Discount_Type IN ('Percent','Baht')),
    CONSTRAINT CHK_Promotion_Status CHECK (Promotion_Status IN ('Active','Ended'))
);

-- TRANSACTION TABLES

-- Table: Order
CREATE TABLE `Order` (
    Order_ID INT NOT NULL,
    Order_Type VARCHAR(20) NOT NULL,
    Order_Status VARCHAR(20) NULL,
    Order_Amount DECIMAL(8,2) NOT NULL,
    Order_DateTime DATE NOT NULL,
    Member_ID INT NOT NULL,
    Branch_ID INT NOT NULL,
    CONSTRAINT PK_Order PRIMARY KEY (Order_ID),
    CONSTRAINT FK_Order_Member FOREIGN KEY (Member_ID)
        REFERENCES Member(Member_ID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT FK_Order_Branch FOREIGN KEY (Branch_ID)
        REFERENCES Branch(Branch_ID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT CHK_Order_Type CHECK (Order_Type IN ('InStorePickup','OrderToTable')),
    CONSTRAINT CHK_Order_Status CHECK (Order_Status IN ('Paid','Cancelled','Completed'))
);

-- Table: InStorePickup (In-store pickup)
CREATE TABLE InStorePickup (
    Order_ID INT NOT NULL,
    Pickup_Time DATE NOT NULL,
    Pickup_Status VARCHAR(20) NULL,
    CONSTRAINT PK_InStorePickup PRIMARY KEY (Order_ID),
    CONSTRAINT FK_InStorePickup_Order FOREIGN KEY (Order_ID)
        REFERENCES `Order`(Order_ID)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT CHK_Pickup_Status CHECK (Pickup_Status IN ('Waiting','Picked','Late'))
);

-- Table: OrderToTable
CREATE TABLE OrderToTable (
    Order_ID INT NOT NULL,
    Table_Number INT NOT NULL,
    CONSTRAINT PK_OrderToTable PRIMARY KEY (Order_ID),
    CONSTRAINT FK_OrderToTable_Order FOREIGN KEY (Order_ID)
        REFERENCES `Order`(Order_ID)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- Table: Receipt
CREATE TABLE Receipt (
    Receipt_ID INT NOT NULL,
    Receipt_Date DATE NULL,
    Tax_ID VARCHAR(13) NULL,
    Discount DECIMAL(8,2) NULL,
    Tax_Address VARCHAR(200) NULL,
    Order_ID INT NOT NULL,
    CONSTRAINT PK_Receipt PRIMARY KEY (Receipt_ID),
    CONSTRAINT FK_Receipt_Order FOREIGN KEY (Order_ID)
        REFERENCES `Order`(Order_ID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- Table: Contain
CREATE TABLE Contain (
    Product_ID INT NOT NULL,
    Order_ID INT NOT NULL,
    Customize VARCHAR(200) NULL,
    Quantity INT NOT NULL,
    Price DECIMAL(8,2) NOT NULL,
    Size VARCHAR(10) NULL,
    CONSTRAINT PK_Contain PRIMARY KEY (Product_ID, Order_ID),
    CONSTRAINT FK_Contain_Product FOREIGN KEY (Product_ID)
        REFERENCES Product(Product_ID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT FK_Contain_Order FOREIGN KEY (Order_ID)
        REFERENCES `Order`(Order_ID)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT CHK_Quantity CHECK (Quantity BETWEEN 1 AND 99),
    CONSTRAINT CHK_Size CHECK (Size IN ('Short','Tall','Grande','Venti'))
);

-- Table: Offer
CREATE TABLE Offer (
    Product_ID INT NOT NULL,
    Branch_ID INT NOT NULL,
    Promotion_ID INT NOT NULL,
    Created_Date DATE NOT NULL,
    CONSTRAINT PK_Offer PRIMARY KEY (Product_ID, Branch_ID, Promotion_ID),
    CONSTRAINT FK_Offer_Product FOREIGN KEY (Product_ID)
        REFERENCES Product(Product_ID)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT FK_Offer_Branch FOREIGN KEY (Branch_ID)
        REFERENCES Branch(Branch_ID)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT FK_Offer_Promotion FOREIGN KEY (Promotion_ID)
        REFERENCES Promotion(Promotion_ID)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- Insert Members 
INSERT INTO Member (Member_ID, Member_Name, E_mail, Phone_Number, Date_of_Birth, Points, Registration_Date, Member_Level, Member_Status)
VALUES (100001, 'John Smith', 'john.smith@example.com', '0891234567', '1990-01-15', 50, '2024-01-01', 'Green', 'Active');
INSERT INTO Member (Member_ID, Member_Name, E_mail, Phone_Number, Date_of_Birth, Points, Registration_Date, Member_Level, Member_Status)
VALUES (100002, 'Emma Brown', 'emma.brown@example.com', '0891234568', '1991-02-15', 100, '2024-02-01', 'Green', 'Active');
INSERT INTO Member (Member_ID, Member_Name, E_mail, Phone_Number, Date_of_Birth, Points, Registration_Date, Member_Level, Member_Status)
VALUES (100003, 'Michael Johnson', 'michael.johnson@example.com', '0891234569', '1992-03-15', 150, '2024-03-01', 'Green', 'Active');
INSERT INTO Member (Member_ID, Member_Name, E_mail, Phone_Number, Date_of_Birth, Points, Registration_Date, Member_Level, Member_Status)
VALUES (100004, 'Olivia Williams', 'olivia.williams@example.com', '0891234570', '1993-04-15', 200, '2024-04-01', 'Green', 'Active');
INSERT INTO Member (Member_ID, Member_Name, E_mail, Phone_Number, Date_of_Birth, Points, Registration_Date, Member_Level, Member_Status)
VALUES (100005, 'Liam Taylor', 'liam.taylor@example.com', '0891234571', '1994-05-15', 250, '2024-05-01', 'Green', 'Active');
INSERT INTO Member (Member_ID, Member_Name, E_mail, Phone_Number, Date_of_Birth, Points, Registration_Date, Member_Level, Member_Status)
VALUES (100006, 'Sophia Martinez', 'sophia.martinez@example.com', '0891234572', '1995-06-15', 300, '2024-06-01', 'Gold', 'Active');
INSERT INTO Member (Member_ID, Member_Name, E_mail, Phone_Number, Date_of_Birth, Points, Registration_Date, Member_Level, Member_Status)
VALUES (100007, 'Daniel Garcia', 'daniel.garcia@example.com', '0891234573', '1996-07-15', 350, '2024-07-01', 'Gold', 'Active');
INSERT INTO Member (Member_ID, Member_Name, E_mail, Phone_Number, Date_of_Birth, Points, Registration_Date, Member_Level, Member_Status)
VALUES (100008, 'Isabella Rodriguez', 'isabella.rodriguez@example.com', '0891234574', '1997-08-15', 400, '2024-08-01', 'Gold', 'Active');
INSERT INTO Member (Member_ID, Member_Name, E_mail, Phone_Number, Date_of_Birth, Points, Registration_Date, Member_Level, Member_Status)
VALUES (100009, 'Ethan Lee', 'ethan.lee@example.com', '0891234575', '1998-09-15', 450, '2024-09-01', 'Gold', 'Active');
INSERT INTO Member (Member_ID, Member_Name, E_mail, Phone_Number, Date_of_Birth, Points, Registration_Date, Member_Level, Member_Status)
VALUES (100010, 'Ava Wilson', 'ava.wilson@example.com', '0891234576', '1999-01-15', 500, '2024-01-01', 'Gold', 'Active');

-- Insert Member Addresses 
INSERT INTO Member_Address (Member_ID, Member_Address)
VALUES (100001, '100/1 Sukhumvit 63 Rd, Ekkamai, Bangkok, Thailand');
INSERT INTO Member_Address (Member_ID, Member_Address)
VALUES (100002, '123/2 Ratchaphruek Rd, Taling Chan, Bangkok, Thailand');
INSERT INTO Member_Address (Member_ID, Member_Address)
VALUES (100003, '45 Soi Ramkhamhaeng 24, Suan Luang, Bangkok, Thailand');
INSERT INTO Member_Address (Member_ID, Member_Address)
VALUES (100004, '88/4 Phahonyothin Rd, Chatuchak, Bangkok, Thailand');
INSERT INTO Member_Address (Member_ID, Member_Address)
VALUES (100005, '12/8 Phaya Thai Rd, Ratchathewi, Bangkok, Thailand');
INSERT INTO Member_Address (Member_ID, Member_Address)
VALUES (100006, '321/7 Silom Rd, Bang Rak, Bangkok, Thailand');
INSERT INTO Member_Address (Member_ID, Member_Address)
VALUES (100007, '250/5 Rama 2 Rd, Samae Dam, Bangkok, Thailand');
INSERT INTO Member_Address (Member_ID, Member_Address)
VALUES (100008, '16/3 Sukhumvit 71 Rd, Phra Khanong, Bangkok, Thailand');
INSERT INTO Member_Address (Member_ID, Member_Address)
VALUES (100009, '90/2 Sathorn Rd, Yan Nawa, Bangkok, Thailand');
INSERT INTO Member_Address (Member_ID, Member_Address)
VALUES (100010, '55/10 Nakhon Ratchasima Rd, Pak Chong, Nakhon Ratchasima, Thailand');

-- Insert Branches
INSERT INTO Branch (Branch_ID, Branch_Name, Location, Opening_Hours, Contact_Number, Store_Type, Branch_Manager, Branch_Status)
VALUES (1001, 'Starbucks Siam Paragon',     'Siam Paragon, Bangkok', '07:00-22:00', '021234567', 'Coffee House', 'Somchai A.', 'Open');
INSERT INTO Branch (Branch_ID, Branch_Name, Location, Opening_Hours, Contact_Number, Store_Type, Branch_Manager, Branch_Status)
VALUES (1002, 'Starbucks CentralWorld',     'CentralWorld, Bangkok', '08:00-22:00', '021234568', 'Coffee House', 'Suda B.',    'Open');
INSERT INTO Branch (Branch_ID, Branch_Name, Location, Opening_Hours, Contact_Number, Store_Type, Branch_Manager, Branch_Status)
VALUES (1003, 'Starbucks Drive Thru Rama 2','Rama 2 Rd, Bangkok',    '06:30-21:30', '021234569', 'Drive Thru',   'Anan C.',   'Open');
INSERT INTO Branch (Branch_ID, Branch_Name, Location, Opening_Hours, Contact_Number, Store_Type, Branch_Manager, Branch_Status)
VALUES (1004, 'Starbucks ICONSIAM',         'ICONSIAM, Bangkok',     '08:00-23:00', '021234570', 'Coffee House', 'Ploy D.',   'Open');
INSERT INTO Branch (Branch_ID, Branch_Name, Location, Opening_Hours, Contact_Number, Store_Type, Branch_Manager, Branch_Status)
VALUES (1005, 'Starbucks Chiang Mai Nimman','Nimman Rd, Chiang Mai', '07:00-21:00', '053123456', 'Coffee House', 'Napat E.',  'Renovation');

-- Insert Product
INSERT INTO Product (Product_ID, Product_Name, Product_Description, Is_Active, Is_Seasonal, Type_Product)
VALUES (200001, 'Caffè Americano',      'Hot espresso with hot water',      1, 0, 'Beverage');
INSERT INTO Product (Product_ID, Product_Name, Product_Description, Is_Active, Is_Seasonal, Type_Product)
VALUES (200002, 'Caffè Latte',          'Espresso with steamed milk',       1, 0, 'Beverage');
INSERT INTO Product (Product_ID, Product_Name, Product_Description, Is_Active, Is_Seasonal, Type_Product)
VALUES (200003, 'Caramel Macchiato',    'Espresso with vanilla, milk, caramel drizzle', 1, 0, 'Beverage');
INSERT INTO Product (Product_ID, Product_Name, Product_Description, Is_Active, Is_Seasonal, Type_Product)
VALUES (200004, 'Green Tea Frappuccino', 'Blended matcha beverage',          1, 1, 'Beverage');
INSERT INTO Product (Product_ID, Product_Name, Product_Description, Is_Active, Is_Seasonal, Type_Product)
VALUES (200005, 'Chocolate Chunk Cookie','Baked cookie with chocolate chunks', 1, 0, 'Food');
INSERT INTO Product (Product_ID, Product_Name, Product_Description, Is_Active, Is_Seasonal, Type_Product)
VALUES (200006, 'Blueberry Cheesecake',  'Slice of blueberry cheesecake',   1, 0, 'Food');
INSERT INTO Product (Product_ID, Product_Name, Product_Description, Is_Active, Is_Seasonal, Type_Product)
VALUES (200007, 'Ham & Cheese Croissant','Croissant with ham and cheese',   1, 0, 'Food');
INSERT INTO Product (Product_ID, Product_Name, Product_Description, Is_Active, Is_Seasonal, Type_Product)
VALUES (200008, 'Reusable Cold Cup 24oz','Plastic reusable cold cup',       1, 0, 'Merch');
INSERT INTO Product (Product_ID, Product_Name, Product_Description, Is_Active, Is_Seasonal, Type_Product)
VALUES (200009, 'Starbucks Mug 12oz',    'Ceramic mug',                     1, 0, 'Merch');
INSERT INTO Product (Product_ID, Product_Name, Product_Description, Is_Active, Is_Seasonal, Type_Product)
VALUES (200010, 'Pumpkin Spice Latte',   'Seasonal pumpkin spice latte',    1, 1, 'Beverage');

-- Insert Promotion
INSERT INTO Promotion (Promotion_ID, Promotion_Name, Start_Date, End_Date, Description, Discount_Type, Promotion_Status)
VALUES (300001, 'Happy Morning 10% Off',       '2025-10-01', '2025-10-31', '10% off all hot coffees before 11 AM',    'Percent', 'Ended');
INSERT INTO Promotion (Promotion_ID, Promotion_Name, Start_Date, End_Date, Description, Discount_Type, Promotion_Status)
VALUES (300002, 'Buy 1 Get 1 Frappuccino',     '2025-11-01', '2025-11-07', 'Buy one get one on selected Frappuccino', 'Percent', 'Ended');
INSERT INTO Promotion (Promotion_ID, Promotion_Name, Start_Date, End_Date, Description, Discount_Type, Promotion_Status)
VALUES (300003, 'Green Level Welcome 50 Baht', '2025-01-01', '2025-12-31', '50 THB discount for new Green members',    'Baht',    'Active');
INSERT INTO Promotion (Promotion_ID, Promotion_Name, Start_Date, End_Date, Description, Discount_Type, Promotion_Status)
VALUES (300004, 'Gold Member Double Stars',    '2025-11-01', '2025-11-30', 'Double points for Gold members',           'Percent', 'Active');
INSERT INTO Promotion (Promotion_ID, Promotion_Name, Start_Date, End_Date, Description, Discount_Type, Promotion_Status)
VALUES (300005, 'Holiday Season Set',          '2025-12-01', '2025-12-31', 'Discounted drink + dessert set',           'Baht',    'Active');

-- Insert Orders 
INSERT INTO `Order` (Order_ID, Order_Type, Order_Status, Order_Amount, Order_DateTime, Member_ID, Branch_ID)
VALUES (400001, 'InStorePickup', 'Paid',      120.00, '2025-11-01', 100001, 1001);
INSERT INTO `Order` (Order_ID, Order_Type, Order_Status, Order_Amount, Order_DateTime, Member_ID, Branch_ID)
VALUES (400002, 'OrderToTable',  'Paid',      145.00, '2025-11-02', 100002, 1002);
INSERT INTO `Order` (Order_ID, Order_Type, Order_Status, Order_Amount, Order_DateTime, Member_ID, Branch_ID)
VALUES (400003, 'InStorePickup', 'Paid',      170.00, '2025-11-03', 100003, 1003);
INSERT INTO `Order` (Order_ID, Order_Type, Order_Status, Order_Amount, Order_DateTime, Member_ID, Branch_ID)
VALUES (400004, 'OrderToTable',  'Paid',      165.00, '2025-11-04', 100004, 1004);
INSERT INTO `Order` (Order_ID, Order_Type, Order_Status, Order_Amount, Order_DateTime, Member_ID, Branch_ID)
VALUES (400005, 'InStorePickup', 'Paid',      190.00, '2025-11-05', 100005, 1005);
INSERT INTO `Order` (Order_ID, Order_Type, Order_Status, Order_Amount, Order_DateTime, Member_ID, Branch_ID)
VALUES (400006, 'OrderToTable',  'Paid',      215.00, '2025-11-01', 100006, 1001);
INSERT INTO `Order` (Order_ID, Order_Type, Order_Status, Order_Amount, Order_DateTime, Member_ID, Branch_ID)
VALUES (400007, 'InStorePickup', 'Paid',      210.00, '2025-11-02', 100007, 1002);
INSERT INTO `Order` (Order_ID, Order_Type, Order_Status, Order_Amount, Order_DateTime, Member_ID, Branch_ID)
VALUES (400008, 'OrderToTable',  'Paid',      235.00, '2025-11-03', 100008, 1003);
INSERT INTO `Order` (Order_ID, Order_Type, Order_Status, Order_Amount, Order_DateTime, Member_ID, Branch_ID)
VALUES (400009, 'InStorePickup', 'Paid',      260.00, '2025-11-04', 100009, 1004);
INSERT INTO `Order` (Order_ID, Order_Type, Order_Status, Order_Amount, Order_DateTime, Member_ID, Branch_ID)
VALUES (400010, 'OrderToTable',  'Paid',      255.00, '2025-11-05', 100010, 1005);
INSERT INTO `Order` (Order_ID, Order_Type, Order_Status, Order_Amount, Order_DateTime, Member_ID, Branch_ID)
VALUES (400011, 'InStorePickup', 'Completed', 280.00, '2025-11-01', 100001, 1001);
INSERT INTO `Order` (Order_ID, Order_Type, Order_Status, Order_Amount, Order_DateTime, Member_ID, Branch_ID)
VALUES (400012, 'OrderToTable',  'Completed', 305.00, '2025-11-02', 100002, 1002);
INSERT INTO `Order` (Order_ID, Order_Type, Order_Status, Order_Amount, Order_DateTime, Member_ID, Branch_ID)
VALUES (400013, 'InStorePickup', 'Completed', 300.00, '2025-11-03', 100003, 1003);
INSERT INTO `Order` (Order_ID, Order_Type, Order_Status, Order_Amount, Order_DateTime, Member_ID, Branch_ID)
VALUES (400014, 'OrderToTable',  'Cancelled', 325.00, '2025-11-04', 100004, 1004);
INSERT INTO `Order` (Order_ID, Order_Type, Order_Status, Order_Amount, Order_DateTime, Member_ID, Branch_ID)
VALUES (400015, 'InStorePickup', 'Cancelled', 350.00, '2025-11-05', 100005, 1005);

-- Insert In-Store Pickup 
INSERT INTO InStorePickup (Order_ID, Pickup_Time, Pickup_Status)
VALUES (400001, '2025-11-01', 'Waiting');
INSERT INTO InStorePickup (Order_ID, Pickup_Time, Pickup_Status)
VALUES (400003, '2025-11-03', 'Waiting');
INSERT INTO InStorePickup (Order_ID, Pickup_Time, Pickup_Status)
VALUES (400005, '2025-11-05', 'Waiting');
INSERT INTO InStorePickup (Order_ID, Pickup_Time, Pickup_Status)
VALUES (400007, '2025-11-02', 'Waiting');
INSERT INTO InStorePickup (Order_ID, Pickup_Time, Pickup_Status)
VALUES (400009, '2025-11-04', 'Waiting');
INSERT INTO InStorePickup (Order_ID, Pickup_Time, Pickup_Status)
VALUES (400011, '2025-11-01', 'Picked');
INSERT INTO InStorePickup (Order_ID, Pickup_Time, Pickup_Status)
VALUES (400013, '2025-11-03', 'Picked');

-- Insert Order To Table records
INSERT INTO OrderToTable (Order_ID, Table_Number)
VALUES (400002, 2);
INSERT INTO OrderToTable (Order_ID, Table_Number)
VALUES (400004, 4);
INSERT INTO OrderToTable (Order_ID, Table_Number)
VALUES (400006, 6);
INSERT INTO OrderToTable (Order_ID, Table_Number)
VALUES (400008, 8);
INSERT INTO OrderToTable (Order_ID, Table_Number)
VALUES (400010, 10);
INSERT INTO OrderToTable (Order_ID, Table_Number)
VALUES (400012, 2);

-- Insert Receipts  
INSERT INTO Receipt (Receipt_ID, Receipt_Date, Tax_ID, Discount, Tax_Address, Order_ID)
VALUES (500001, '2025-11-01', '0105547000001', 10.00, 'Starbucks Thailand Co., Ltd., Bangkok', 400001);
INSERT INTO Receipt (Receipt_ID, Receipt_Date, Tax_ID, Discount, Tax_Address, Order_ID)
VALUES (500002, '2025-11-02', '0105547000002',  0.00, 'Starbucks Thailand Co., Ltd., Bangkok', 400002);
INSERT INTO Receipt (Receipt_ID, Receipt_Date, Tax_ID, Discount, Tax_Address, Order_ID)
VALUES (500003, '2025-11-03', '0105547000003',  0.00, 'Starbucks Thailand Co., Ltd., Bangkok', 400003);
INSERT INTO Receipt (Receipt_ID, Receipt_Date, Tax_ID, Discount, Tax_Address, Order_ID)
VALUES (500004, '2025-11-04', '0105547000004', 10.00, 'Starbucks Thailand Co., Ltd., Bangkok', 400004);
INSERT INTO Receipt (Receipt_ID, Receipt_Date, Tax_ID, Discount, Tax_Address, Order_ID)
VALUES (500005, '2025-11-05', '0105547000005',  0.00, 'Starbucks Thailand Co., Ltd., Bangkok', 400005);
INSERT INTO Receipt (Receipt_ID, Receipt_Date, Tax_ID, Discount, Tax_Address, Order_ID)
VALUES (500006, '2025-11-01', '0105547000006',  0.00, 'Starbucks Thailand Co., Ltd., Bangkok', 400006);
INSERT INTO Receipt (Receipt_ID, Receipt_Date, Tax_ID, Discount, Tax_Address, Order_ID)
VALUES (500007, '2025-11-02', '0105547000007', 10.00, 'Starbucks Thailand Co., Ltd., Bangkok', 400007);
INSERT INTO Receipt (Receipt_ID, Receipt_Date, Tax_ID, Discount, Tax_Address, Order_ID)
VALUES (500008, '2025-11-03', '0105547000008',  0.00, 'Starbucks Thailand Co., Ltd., Bangkok', 400008);
INSERT INTO Receipt (Receipt_ID, Receipt_Date, Tax_ID, Discount, Tax_Address, Order_ID)
VALUES (500009, '2025-11-04', '0105547000009',  0.00, 'Starbucks Thailand Co., Ltd., Bangkok', 400009);
INSERT INTO Receipt (Receipt_ID, Receipt_Date, Tax_ID, Discount, Tax_Address, Order_ID)
VALUES (500010, '2025-11-05', '010554700010', 10.00, 'Starbucks Thailand Co., Ltd., Bangkok', 400010);
INSERT INTO Receipt (Receipt_ID, Receipt_Date, Tax_ID, Discount, Tax_Address, Order_ID)
VALUES (500011, '2025-11-01', '0105547000011',  0.00, 'Starbucks Thailand Co., Ltd., Bangkok', 400011);
INSERT INTO Receipt (Receipt_ID, Receipt_Date, Tax_ID, Discount, Tax_Address, Order_ID)
VALUES (500012, '2025-11-02', '0105547000012',  0.00, 'Starbucks Thailand Co., Ltd., Bangkok', 400012);
INSERT INTO Receipt (Receipt_ID, Receipt_Date, Tax_ID, Discount, Tax_Address, Order_ID)
VALUES (500013, '2025-11-03', '0105547000013', 10.00, 'Starbucks Thailand Co., Ltd., Bangkok', 400013);
INSERT INTO Receipt (Receipt_ID, Receipt_Date, Tax_ID, Discount, Tax_Address, Order_ID)
VALUES (500014, '2025-11-04', '0105547000014',  0.00, 'Starbucks Thailand Co., Ltd., Bangkok', 400014);
INSERT INTO Receipt (Receipt_ID, Receipt_Date, Tax_ID, Discount, Tax_Address, Order_ID)
VALUES (500015, '2025-11-05', '0105547000015',  0.00, 'Starbucks Thailand Co., Ltd., Bangkok', 400015);

-- Insert Contain 
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200001, 400001, NULL,                  1,       120.00, 'Tall');
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200002, 400001, 'Less ice',     2,       130.00, 'Grande');
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200003, 400002, 'Non-fat milk', 3,       140.00, 'Venti');
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200004, 400002, 'Extra shot',   1,       150.00, 'Tall');
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200005, 400003, NULL,           2,       160.00, NULL);
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200006, 400003, NULL,           3,       120.00, NULL);
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200007, 400004, NULL,           1,       130.00, NULL);
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200008, 400004, NULL,           2,       140.00, NULL);
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200009, 400005, NULL,           3,       150.00, NULL);
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200010, 400005, 'Extra shot',   1,       160.00, 'Tall');
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200001, 400006, NULL,           2,       120.00, 'Grande');
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200002, 400006, 'Non-fat milk', 3,       130.00, 'Venti');
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200003, 400007, 'Extra shot',   1,       140.00, 'Tall');
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200004, 400007, 'Less ice',     2,       150.00, 'Grande');
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200005, 400008, NULL,           3,       160.00, NULL);
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200006, 400008, NULL,           1,       120.00, NULL);
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200007, 400009, NULL,           2,       130.00, NULL);
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200008, 400009, NULL,           3,       140.00, NULL);
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200009, 400010, NULL,           1,       150.00, NULL);
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200010, 400010, 'Less ice',     2,       160.00, 'Grande');
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200001, 400011, NULL,           3,       120.00, 'Venti');
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200002, 400011, 'Extra shot',   1,       130.00, 'Tall');
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200003, 400012, 'Less ice',     2,       140.00, 'Grande');
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200004, 400012, 'Non-fat milk', 3,       150.00, 'Venti');
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200005, 400013, NULL,           1,       160.00, NULL);
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200006, 400013, NULL,           2,       120.00, NULL);
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200007, 400014, NULL,           3,       130.00, NULL);
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200008, 400014, NULL,           1,       140.00, NULL);
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200009, 400015, NULL,           2,       150.00, NULL);
INSERT INTO Contain (Product_ID, Order_ID, Customize,           Quantity, Price,  Size)
VALUES (200010, 400015, 'Non-fat milk', 3,       160.00, 'Venti');

-- Insert Offer  
INSERT INTO Offer (Product_ID, Branch_ID, Promotion_ID, Created_Date)
VALUES (200001, 1001, 300001, '2025-10-01');
INSERT INTO Offer (Product_ID, Branch_ID, Promotion_ID, Created_Date)
VALUES (200002, 1001, 300002, '2025-11-01');
INSERT INTO Offer (Product_ID, Branch_ID, Promotion_ID, Created_Date)
VALUES (200004, 1002, 300002, '2025-11-01');
INSERT INTO Offer (Product_ID, Branch_ID, Promotion_ID, Created_Date)
VALUES (200010, 1003, 300005, '2025-12-01');
INSERT INTO Offer (Product_ID, Branch_ID, Promotion_ID, Created_Date)
VALUES (200005, 1004, 300003, '2025-01-05');
INSERT INTO Offer (Product_ID, Branch_ID, Promotion_ID, Created_Date)
VALUES (200006, 1004, 300005, '2025-12-01');
INSERT INTO Offer (Product_ID, Branch_ID, Promotion_ID, Created_Date)
VALUES (200007, 1002, 300004, '2025-11-05');
INSERT INTO Offer (Product_ID, Branch_ID, Promotion_ID, Created_Date)
VALUES (200008, 1005, 300003, '2025-02-01');

