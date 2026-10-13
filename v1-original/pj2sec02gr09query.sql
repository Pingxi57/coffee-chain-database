USE pj2sec02gr09db;

SELECT * FROM Member;
SELECT * FROM Member_Address;
SELECT * FROM Product;
SELECT * FROM Branch;
SELECT * FROM Promotion;
SELECT * FROM `Order`;
SELECT * FROM InStorePickup;
SELECT * FROM OrderToTable;
SELECT * FROM Receipt;
SELECT * FROM Contain;
SELECT * FROM Offer;

-- < 6788057 Sirirampa Luangphiphatsorn >
-- Query 1: Active members with more than 100 points
SELECT Member_ID, Member_Name, Points, Member_Status
FROM Member
WHERE Points > 100 AND Member_Status = 'Active';
-- Query 2: Top 5 oldest active members (age from Date_of_Birth)
SELECT Member_ID, Member_Name, Date_of_Birth, TIMESTAMPDIFF(YEAR, Date_of_Birth, CURDATE()) AS Age, Member_Level
FROM Member
WHERE Member_Status = 'Active'
ORDER BY Age DESC, Member_ID
LIMIT 5;
-- Query 3: High-spending members with average order value
SELECT m.Member_ID, m.Member_Name, AVG(o.Order_Amount) AS Average_Spending
FROM `Order`
GROUP BY m.Member_ID, m.Member_Name
HAVING AVG(o.Order_Amount) > 200; 
-- Query 4: Orders placed by each member
SELECT m.Member_Name, o.Order_ID, o.Order_Amount
FROM Member m
INNER JOIN `Order` o ON m.Member_ID = o.Member_ID;
-- Query 5: All branches and their number of orders (LEFT OUTER JOIN)
SELECT o.Branch_ID, b.Branch_Name, COUNT(o.Order_ID) AS Total_Orders
FROM Branch b
LEFT OUTER JOIN `Order` o ON b.Branch_ID = o.Branch_ID
GROUP BY b.Branch_Name;

-- < 6788103 Chanachon Ruanpheng >
-- Query 1: All product that is now selling.
SELECT Product_Name, Product_Id
FROM Product
WHERE is_active = 1 AND is_seasonal = 1;
-- Query 2: All member that born in this month so we can make birthday promotion 
SELECT member_id, member_name, Date_of_Birth, Poins
FROM Member
WHERE MONTH(Date_of_Birth) = 12;
-- Query 3: Summarize top selling food products
SELECT
    p.Product_Name,
    SUM(c.Quantity) AS Total_Quantity_Sold, 
    AVG(c.Price) AS Average_Item_Price     
FROM Product p
INNER JOIN Contain c ON p.Product_ID = c.Product_ID
WHERE p.Type_Product = 'Food'
GROUP BY p.Product_ID, p.Product_Name
HAVING SUM(c.Quantity) > 1                     
ORDER BY Total_Quantity_Sold DESC;
-- Query 4: Orders Including Product Name and Branch Location
SELECT o.Order_ID, p.Product_Name, c.Quantity, b.Branch_Name, b.Location
FROM `Order` o
INNER JOIN Contain c ON o.Order_ID = c.Order_ID  
INNER JOIN Product p ON c.Product_ID = p.Product_ID 
INNER JOIN Branch b ON o.Branch_ID = b.Branch_ID 
WHERE o.Order_DateTime = CURDATE();
-- Query 5: Products Not Included in Any Order
SELECT p.Product_ID, p.Product_Name, p.Type_Product, IFNULL(SUM(c.Quantity), 0) AS Total_Quantity_Sold
FROM Product p
LEFT OUTER JOIN Contain c ON p.Product_ID = c.Product_ID
GROUP BY p.Product_ID, p.Product_Name, p.Type_Product
ORDER BY Total_Quantity_Sold ASC, p.Product_ID;

-- < 6788109 Yanapat Sittirat >
-- Query 1: Members with the most recent order
SELECT m.Member_ID, m.Member_Name, o.Order_ID, o.Order_DateTime
FROM Member m
INNER JOIN `Order` o ON m.Member_ID = o.Member_ID
WHERE o.Order_DateTime = (SELECT MAX(Order_DateTime) FROM `Order` WHERE Member_ID = m.Member_ID);
-- Query 2: Total sales per product (using SUM() and GROUP BY)
SELECT p.Product_Name, SUM(c.Price * c.Quantity) AS Total_Sales
FROM Product p
INNER JOIN Contain c ON p.Product_ID = c.Product_ID
GROUP BY p.Product_Name;
-- Query 3: Count of members who have placed an order
SELECT COUNT(DISTINCT m.Member_ID) AS Members_With_Orders
FROM Member m
INNER JOIN `Order` o ON m.Member_ID = o.Member_ID;
-- Query 4: Branches with the highest order value
SELECT b.Branch_Name, SUM(o.Order_Amount) AS Total_Value
FROM Branch b
INNER JOIN `Order` o ON b.Branch_ID = o.Branch_ID
GROUP BY b.Branch_Name
ORDER BY Total_Value DESC
LIMIT 1;
-- Query 5: Products on offer at each branch
SELECT p.Product_Name, b.Branch_Name, pr.Promotion_Name
FROM Product p
LEFT OUTER JOIN Offer o ON p.Product_ID = o.Product_ID
LEFT OUTER JOIN Branch b ON o.Branch_ID = b.Branch_ID
LEFT OUTER JOIN Promotion pr ON o.Promotion_ID = pr.Promotion_ID
WHERE pr.Promotion_Status = 'Active' OR pr.Promotion_ID IS NULL;

-- < 6788119 Chanapron Sumkhemthong >
-- Query 1: Active Members with Mid-High Points Range
SELECT Member_ID, Member_Name, Points, Member_Level
FROM Member
WHERE Member_Status = 'Active' AND Points BETWEEN 200 AND 500;
-- Query 2: Display Active Member Information
SELECT CONCAT(Member_Name, ' (', Email, ') - Status: ', Member_Status) AS 'Member Info'
FROM Member
WHERE Member_Status = 'Active';
-- Query 3: Spending Summary Per Member
SELECT M.Member_ID, M.Member_Name, COUNT(O.Order_ID) AS Total_Orders, SUM(O.Order_Amount) AS Total_Spending
FROM Member M
JOIN `Order` O ON M.Member_ID = O.Member_ID
GROUP BY M.Member_ID
HAVING COUNT(O.Order_ID) >= 2 AND SUM(O.Order_Amount) >= 400;
-- Query 4: Orders from Coffee House Branches (INNER JOIN)
SELECT O.Order_ID, M.Member_Name, B.Branch_Name, O.Order_Amount
FROM `Order` O
JOIN Member M ON O.Member_ID = M.Member_ID
JOIN Branch B ON O.Branch_ID = B.Branch_ID
WHERE B.Store_Type = 'Coffee House';
-- Query 5: Show Branches with Active Promotions and Their Number of Orders
SELECT B.Branch_ID, B.Branch_Name, COUNT(O.Order_ID) AS Total_Orders
FROM Branch B
LEFT OUTER JOIN `Order` O ON B.Branch_ID = O.Branch_ID
LEFT JOIN Offer F ON B.Branch_ID = F.Branch_ID
LEFT JOIN Promotion P ON F.Promotion_ID = P.Promotion_ID
WHERE P.Promotion_Status = 'Active' OR P.Promotion_ID IS NULL
GROUP BY B.Branch_ID
ORDER BY Total_Orders DESC;

-- < 6788219 Ratchanon Srithongkul >
-- Query 1: Display active Gold members with at least 400 points. 
SELECT Member_ID, Member_Name, Member_Level, Points, Member_Status
FROM Member
WHERE Member_Status = 'Active'
  AND Member_Level = 'Gold'
  AND Points >= 400
ORDER BY Points DESC;
-- Query 2: Show members' age in years and convert names to uppercase.
SELECT Member_ID,
       UPPER(Member_Name) AS Member_Name_Upper,
       TIMESTAMPDIFF(YEAR, Date_of_Birth, CURDATE()) AS Age,
       Member_Level
FROM Member
WHERE TIMESTAMPDIFF(YEAR, Date_of_Birth, CURDATE()) >= 25
ORDER BY Age DESC;
-- Query 3: Summarize total number of orders and total spending per member who spent over 500.
SELECT m.Member_ID, m.Member_Name,
       COUNT(o.Order_ID) AS Total_Orders,
       SUM(o.Order_Amount) AS Total_Spending
FROM Member m
INNER JOIN `Order` o ON m.Member_ID = o.Member_ID
GROUP BY m.Member_ID, m.Member_Name
HAVING SUM(o.Order_Amount) > 500
ORDER BY Total_Spending DESC;
-- Query 4: List orders with member name and branch name using INNER JOIN.
SELECT o.Order_ID, m.Member_Name, b.Branch_Name, o.Order_Amount, o.Order_DateTime
FROM `Order` o
INNER JOIN Member m ON o.Member_ID = m.Member_ID
INNER JOIN Branch b ON o.Branch_ID = b.Branch_ID
WHERE o.Order_Status = 'Paid'
ORDER BY o.Order_DateTime;
-- Query 5: Show all branches including those with no orders.
SELECT b.Branch_ID, b.Branch_Name, COUNT(o.Order_ID) AS Total_Orders
FROM Branch b
LEFT JOIN `Order` o ON b.Branch_ID = o.Branch_ID
GROUP BY b.Branch_ID, b.Branch_Name
ORDER BY Total_Orders DESC;

