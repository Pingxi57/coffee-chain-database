-- =====================================================================
-- Data verification checks — run after loading seed data.
-- Every "should be 0" check must return 0.
-- =====================================================================
USE coffee_chain_db;

-- 1. Row counts
SELECT 'Member' AS table_name, COUNT(*) AS row_count FROM Member
UNION ALL SELECT 'Member_Address',    COUNT(*) FROM Member_Address
UNION ALL SELECT 'Branch',            COUNT(*) FROM Branch
UNION ALL SELECT 'Product',           COUNT(*) FROM Product
UNION ALL SELECT 'Promotion',         COUNT(*) FROM Promotion
UNION ALL SELECT 'Starbucks_Card',    COUNT(*) FROM Starbucks_Card
UNION ALL SELECT 'Orders',            COUNT(*) FROM Orders
UNION ALL SELECT 'Order_Item',        COUNT(*) FROM Order_Item
UNION ALL SELECT 'InStorePickup',     COUNT(*) FROM InStorePickup
UNION ALL SELECT 'OrderToTable',      COUNT(*) FROM OrderToTable
UNION ALL SELECT 'Delivery',          COUNT(*) FROM Delivery
UNION ALL SELECT 'Receipt',           COUNT(*) FROM Receipt
UNION ALL SELECT 'Payment',           COUNT(*) FROM Payment
UNION ALL SELECT 'Point_Transaction', COUNT(*) FROM Point_Transaction;

-- 2. Integrity checks (all should be 0)
SELECT 'Order_Amount <> sum of items' AS check_name, COUNT(*) AS problems
FROM Orders o
WHERE o.Order_Amount <> (SELECT COALESCE(SUM(Line_Total), 0) FROM Order_Item i WHERE i.Order_ID = o.Order_ID)
UNION ALL
SELECT 'Order without items', COUNT(*)
FROM Orders o WHERE NOT EXISTS (SELECT 1 FROM Order_Item i WHERE i.Order_ID = o.Order_ID)
UNION ALL
SELECT 'Order missing its subtype row', COUNT(*)
FROM Orders o
WHERE (o.Order_Type = 'InStorePickup' AND NOT EXISTS (SELECT 1 FROM InStorePickup x WHERE x.Order_ID = o.Order_ID))
   OR (o.Order_Type = 'OrderToTable'  AND NOT EXISTS (SELECT 1 FROM OrderToTable  x WHERE x.Order_ID = o.Order_ID))
   OR (o.Order_Type = 'Delivery'      AND NOT EXISTS (SELECT 1 FROM Delivery      x WHERE x.Order_ID = o.Order_ID))
UNION ALL
SELECT 'Subtype row does not match Order_Type', COUNT(*)
FROM (SELECT Order_ID, 'InStorePickup' AS t FROM InStorePickup
      UNION ALL SELECT Order_ID, 'OrderToTable' FROM OrderToTable
      UNION ALL SELECT Order_ID, 'Delivery' FROM Delivery) s
JOIN Orders o ON o.Order_ID = s.Order_ID
WHERE o.Order_Type <> s.t
UNION ALL
SELECT 'Payment <> items - discount + delivery fee', COUNT(*)
FROM Payment p
JOIN Orders o        ON o.Order_ID = p.Order_ID
JOIN Receipt r       ON r.Order_ID = p.Order_ID
LEFT JOIN Delivery d ON d.Order_ID = p.Order_ID
WHERE p.Amount <> o.Order_Amount - r.Discount + COALESCE(d.Delivery_Fee, 0)
UNION ALL
SELECT 'Cancelled order with receipt/payment', COUNT(*)
FROM Orders o
WHERE o.Order_Status = 'Cancelled'
  AND (EXISTS (SELECT 1 FROM Receipt r WHERE r.Order_ID = o.Order_ID)
    OR EXISTS (SELECT 1 FROM Payment p WHERE p.Order_ID = o.Order_ID))
UNION ALL
SELECT 'Order placed before member registered', COUNT(*)
FROM Orders o JOIN Member m ON m.Member_ID = o.Member_ID
WHERE DATE(o.Order_DateTime) < m.Registration_Date
UNION ALL
SELECT 'Order-to-Table at a Drive Thru', COUNT(*)
FROM Orders o JOIN Branch b ON b.Branch_ID = o.Branch_ID
WHERE o.Order_Type = 'OrderToTable' AND b.Store_Type = 'Drive Thru'
UNION ALL
SELECT 'Order outside branch opening hours', COUNT(*)
FROM Orders o JOIN Branch b ON b.Branch_ID = o.Branch_ID
WHERE TIME(o.Order_DateTime) < b.Open_Time OR TIME(o.Order_DateTime) > b.Close_Time
UNION ALL
SELECT 'Delivery paid by cash', COUNT(*)
FROM Payment p JOIN Orders o ON o.Order_ID = p.Order_ID
WHERE o.Order_Type = 'Delivery' AND p.Payment_Method = 'Cash'
UNION ALL
SELECT 'Card payment with someone else''s card', COUNT(*)
FROM Payment p JOIN Orders o ON o.Order_ID = p.Order_ID
JOIN Starbucks_Card c ON c.Card_ID = p.Card_ID
WHERE c.Member_ID <> o.Member_ID
UNION ALL
SELECT 'Promotion used outside its dates', COUNT(*)
FROM Orders o JOIN Promotion p ON p.Promotion_ID = o.Promotion_ID
WHERE DATE(o.Order_DateTime) NOT BETWEEN p.Start_Date AND p.End_Date
  AND o.Order_ID > 400018
UNION ALL
SELECT 'Member.Points <> sum of Point_Transaction', COUNT(*)
FROM Member m
WHERE m.Points <> (SELECT COALESCE(SUM(Points_Change), 0) FROM Point_Transaction t WHERE t.Member_ID = m.Member_ID);

-- 3. Quick look at the shape of the data
-- orders per month (should grow over time)
SELECT DATE_FORMAT(Order_DateTime, '%Y-%m') AS month, COUNT(*) AS orders
FROM Orders GROUP BY month ORDER BY month;

-- orders by hour (peaks at morning, lunch, evening)
SELECT HOUR(Order_DateTime) AS hour, COUNT(*) AS orders
FROM Orders GROUP BY hour ORDER BY hour;

-- top 10 products by units sold
SELECT p.Product_Name, SUM(i.Quantity) AS units
FROM Order_Item i JOIN Product p ON p.Product_ID = i.Product_ID
GROUP BY p.Product_ID, p.Product_Name ORDER BY units DESC LIMIT 10;

-- order type and payment method mix
SELECT Order_Type, COUNT(*) AS orders FROM Orders GROUP BY Order_Type;
SELECT Payment_Method, COUNT(*) AS payments FROM Payment GROUP BY Payment_Method;
