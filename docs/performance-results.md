# Phase 4 — Index performance results

**Setup:** 200,018 orders · 378,720 order items · 190,098 payments · 20,010 members  
**Engine:** MySQL 8.0 (InnoDB, default settings) · each query run 15 times, median reported  
**Scripts:** `performance/01_benchmark_queries.sql` → `02_create_indexes.sql` → run 01 again (`03_drop_indexes.sql` resets)

> Times depend on the machine. The **rows read** column (InnoDB handler counters) does not,
> so it is the fairest way to compare before and after.

![Before vs after](performance_before_after.png)

## 1. Results per query

| # | Query | Before | After | Speed-up | Rows read before → after | Access path before → after |
|---|---|---:|---:|---:|---:|---|
| B1 | All orders on one day | 39.4 ms | 1.0 ms | **39×** | 200,022 → 492 | Table scan → Index range scan |
| B2 | Same, written `WHERE DATE(Order_DateTime) = ...` | 30.8 ms | 29.8 ms | none | 200,022 → 200,022 | Table scan → Table scan |
| B3 | One branch, one month, by day | 17.3 ms | 2.1 ms | **8×** | 13,142 → 1,779 | Index lookup (Branch_ID only) → Index range scan (Branch_ID + date) |
| B4 | A member's last 10 orders | 0.9 ms | 0.3 ms | 3× | 261 → 9 | Index lookup + sort → Index lookup, no sort |
| B5 | Daily revenue for one month | 54.4 ms | 9.0 ms | **6×** | 203,841 → 27,447 | Table scan → Covering index range scan |
| B6 | Name search `LIKE 'Krit Th%'` | 4.0 ms | 0.5 ms | **8×** | 20,012 → 30 | Table scan → Index range scan |
| B7 | Name search `LIKE '%Thongdee'` | 6.8 ms | 9.1 ms | none | 20,012 → 20,012 | Table scan → Table scan |
| B8 | Best sellers of the last 7 days (3-table join) | 80.6 ms | 22.8 ms | **4×** | 221,160 → 24,428 | Table scan on Orders → Index range scan + covering lookup |

The whole Phase 3 analytics script (12 queries) went from **9.3 s to 6.4 s**. The biggest gain was
Q10, products bought together: **3.2 s → 1.1 s** thanks to the covering index on Order_Item.

## 2. Indexes created and why

| Index | Columns | Serves | Reason |
|---|---|---|---|
| `idx_orders_datetime` | Order_DateTime | B1, B8, analytics Q2–Q5 | Most reports filter by a date range |
| `idx_orders_branch_datetime` | Branch_ID, Order_DateTime | B3, `sp_branch_report` | Equality column first, range column last |
| `idx_orders_member_datetime` | Member_ID, Order_DateTime | B4, analytics Q7 | Rows come out already sorted by date, so no filesort |
| `idx_payment_paidat` | Paid_At, Payment_Status, Amount | B5, analytics Q1 | Covering: the query never reads the table |
| `idx_order_item_order_product` | Order_ID, Product_ID, Quantity | B8, analytics Q10 | Covering for the item self-join |
| `idx_member_name` | Member_Name | B6 | Prefix search |

**Removed as redundant:** the single-column FK indexes `FK_Orders_Branch`, `FK_Orders_Member` and
`FK_Order_Item_Order`. The new composite indexes start with the same column, so they also serve the foreign keys.

## 3. Lessons learned

**1. A function on the column switches the index off (B2).**
`DATE(Order_DateTime) = '2026-09-30'` and `Order_DateTime >= '2026-09-30' AND < '2026-10-01'`
ask the same question. Only the second one can use the index: 39× faster versus no gain.
This is called a *sargable* condition.

**2. A leading wildcard cannot use a B-tree index (B7).**
The index is sorted by the beginning of the text, like a phone book.
`'Krit Th%'` can jump straight to the right place. `'%Thongdee'` has to read every name.
The fix would be a FULLTEXT index or a separate search engine, not a normal index.

**3. Column order in a composite index matters.**
`(Branch_ID, Order_DateTime)` lets MySQL jump to one branch and then to a date range: 13,142 → 1,779 rows.
The rule is equality columns first, range columns last.

**4. Don't lead an index with a column that has almost no variety.**
The first attempt was `(Payment_Status, Paid_At, Amount)`. 99.99% of payments are `'Success'`, but the
optimizer estimated that only half the rows matched. It then started analytics Q3 from Payment
and made 190,000 random lookups into Orders, which made Q3 **2× slower** (408 → 904 ms).
Moving `Paid_At` to the front fixed it.

**5. MySQL drops redundant foreign-key indexes automatically.**
After `(Branch_ID, Order_DateTime)` was created, MySQL silently removed the implicit `FK_Orders_Branch`
index, because the new index can enforce the foreign key. `02_create_indexes.sql` checks for this before dropping.

**6. Sometimes rewriting the query beats adding an index.**
Analytics Q12, the quiet-days calendar, originally checked `NOT EXISTS` separately for each of
the 1,500 branch-days. Even with the composite index this took about 1.4 s. Summarising September's
orders once and then LEFT JOINing to the calendar takes **about 33 ms (≈40× faster)**.

**7. Indexes are not free.**

| Cost | Before | After |
|---|---:|---:|
| Insert 20,000 orders | 278 ms | 790 ms (≈2.8× slower) |
| Secondary index size on Orders | 14.4 MB | 16.1 MB |
| Secondary index size on Payment | 6.0 MB | 12.6 MB |

Every INSERT now has to update 3 more indexes on Orders. A coffee shop reads its data far more often
than it writes it (dashboards, reports, the app's order history), so this trade-off is worth it here.

**8. The optimizer is not always right.**
Analytics Q1 (revenue by month for *all* payments) got slower: 150 → 220 ms. The optimizer chose to read
the whole new index because its rows are smaller. In practice a plain table scan was faster
(checked with `IGNORE INDEX`). Indexes help when a query needs a *small part* of a table. For
whole-table reports, a scheduled summary table would be the next step.

## 4. How to reproduce

In MySQL Workbench, after loading the data, open and run these files in order:

1. `performance/03_drop_indexes.sql` (only if the indexes already exist)
2. `performance/01_benchmark_queries.sql` → save the EXPLAIN ANALYZE output = **before**
3. `performance/02_create_indexes.sql`
4. `performance/01_benchmark_queries.sql` again → **after**

Optional automatic timing: `pip install pymysql`, then
`python performance/benchmark.py --label before --password ...` (and `--label after`). Results go to `performance/results.csv`.
