"""
Phase 4 benchmark runner (optional — the .sql files are enough for Workbench).

Runs every query in 01_benchmark_queries.sql (without EXPLAIN ANALYZE),
repeats it, and records:
  * median time in ms
  * rows read by the storage engine (sum of Handler_read_* counters)
  * access path from EXPLAIN (table scan / index range / covering index)

Usage:
  pip install pymysql
  python benchmark.py --label before  --password YOUR_PASSWORD
  (run 02_create_indexes.sql)
  python benchmark.py --label after   --password YOUR_PASSWORD
Results are appended to results.csv in this folder.
"""
import argparse, csv, os, re, statistics, time
import pymysql

HERE = os.path.dirname(os.path.abspath(__file__))


def load_queries(path):
    text = open(path, encoding="utf-8").read()
    blocks = re.split(r"\n-- -{20,}\n-- (B\d+)\. ", text)
    queries = []
    for i in range(1, len(blocks), 2):
        qid = blocks[i]
        body = blocks[i + 1]
        title = body.splitlines()[0].strip()
        m = re.search(r"EXPLAIN ANALYZE\s*(SELECT.*?);", body, re.S)
        queries.append((qid, title, m.group(1).strip()))
    return queries


def handler_reads(cur):
    cur.execute("SHOW SESSION STATUS LIKE 'Handler_read%'")
    return sum(int(v) for _, v in cur.fetchall())


def access_path(cur, sql):
    """Short summary of how each table is read, e.g. 'Table scan(o) + Index lookup(i)'."""
    cur.execute("EXPLAIN FORMAT=TREE " + sql)
    tree = cur.fetchone()[0]
    steps = re.findall(r"(Covering index range scan|Covering index lookup|Covering index scan|"
                       r"Index range scan|Index lookup|Index scan|Single-row index lookup|Table scan)"
                       r" on (\w+)", tree)
    seen, out = set(), []
    for kind, tbl in steps:
        if tbl not in seen:
            seen.add(tbl)
            out.append(f"{kind}({tbl})")
    return " + ".join(out) or "other"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--label", required=True)
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--user", default="root")
    ap.add_argument("--password", default="")
    ap.add_argument("--socket", default=None)
    ap.add_argument("--runs", type=int, default=7)
    a = ap.parse_args()

    conn = pymysql.connect(host=a.host, user=a.user, password=a.password,
                           unix_socket=a.socket, database="coffee_chain_db", charset="utf8mb4")
    cur = conn.cursor()
    rows = []
    for qid, title, sql in load_queries(os.path.join(HERE, "01_benchmark_queries.sql")):
        cur.execute(sql); cur.fetchall()                       # warm-up
        before = handler_reads(cur)
        cur.execute(sql); cur.fetchall()
        rows_read = handler_reads(cur) - before - 1            # minus the SHOW itself
        times = []
        for _ in range(a.runs):
            t = time.perf_counter(); cur.execute(sql); cur.fetchall()
            times.append((time.perf_counter() - t) * 1000)
        r = dict(label=a.label, query=qid, title=title, access=access_path(cur, sql),
                 median_ms=round(statistics.median(times), 2), rows_read=rows_read)
        rows.append(r)
        print(f"{qid:4} {r['median_ms']:9.2f} ms  {rows_read:>8} rows read  {r['access']:60}  {title}")

    out = os.path.join(HERE, "results.csv")
    new = not os.path.exists(out)
    with open(out, "a", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        if new:
            w.writeheader()
        w.writerows(rows)
    print("saved ->", out)


if __name__ == "__main__":
    main()
