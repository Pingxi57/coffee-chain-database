-- =====================================================================
-- Phase 4 — 03 Drop indexes (go back to the "before" state)
-- Use this to re-run the "before" benchmark. Restores the original
-- single-column foreign-key indexes first, so the FKs always stay indexed.
-- =====================================================================
USE coffee_chain_db;

CREATE INDEX FK_Orders_Branch ON Orders (Branch_ID);
CREATE INDEX FK_Orders_Member ON Orders (Member_ID);
CREATE INDEX FK_Order_Item_Order ON Order_Item (Order_ID);

DROP INDEX idx_orders_datetime         ON Orders;
DROP INDEX idx_orders_branch_datetime  ON Orders;
DROP INDEX idx_orders_member_datetime  ON Orders;
DROP INDEX idx_payment_paidat          ON Payment;
DROP INDEX idx_member_name             ON Member;
DROP INDEX idx_order_item_order_product ON Order_Item;

ANALYZE TABLE Orders, Order_Item, Payment, Member;
