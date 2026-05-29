-- =============================================================
-- Global DB — Query analysis and index optimisation (Q5)
-- =============================================================

ALTER SESSION SET CONTAINER = G_PDB;
ALTER SESSION SET CURRENT_SCHEMA = pdb_admin;

-- =============================================================
-- Q5-a: Number of orders per client in 2026
--
-- Note: wrapping DATECOMMANDE in EXTRACT() prevents the
-- optimiser from using a plain B-tree index on that column
-- (function result ≠ raw column value).  The range predicate
-- version below (Q5-d) is preferred once the index exists.
-- =============================================================
SELECT
    c.IDCLIENT,
    c.CODECLIENT,
    c.SOCIETE,
    COUNT(cmd.IDCOMMANDE) AS NB_COMMANDES
FROM   CLIENTS c
JOIN   COMMANDES cmd ON c.IDCLIENT = cmd.IDCLIENT
WHERE  EXTRACT(YEAR FROM cmd.DATECOMMANDE) = 2026
GROUP  BY c.IDCLIENT, c.CODECLIENT, c.SOCIETE
ORDER  BY NB_COMMANDES DESC;

-- =============================================================
-- Q5-b: Capture the execution plan BEFORE indexes are created
--
-- Expected costly operations on a cold schema:
--   TABLE ACCESS FULL on COMMANDES  → every row read to apply
--                                     the EXTRACT filter
--   TABLE ACCESS FULL on CLIENTS    → every row read for the join
--   HASH JOIN                       → two full scans hashed in memory
--   SORT ORDER BY                   → extra pass to sort by NB_COMMANDES
-- =============================================================
EXPLAIN PLAN SET STATEMENT_ID = 'before_index' FOR
SELECT
    c.IDCLIENT,
    c.CODECLIENT,
    c.SOCIETE,
    COUNT(cmd.IDCOMMANDE) AS NB_COMMANDES
FROM   CLIENTS c
JOIN   COMMANDES cmd ON c.IDCLIENT = cmd.IDCLIENT
WHERE  EXTRACT(YEAR FROM cmd.DATECOMMANDE) = 2026
GROUP  BY c.IDCLIENT, c.CODECLIENT, c.SOCIETE
ORDER  BY NB_COMMANDES DESC;

-- Q5-c: Display and analyse the plan
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    filter_preds => 'STATEMENT_ID = ''before_index'''
));

/*
  Typical analysis comments
  ─────────────────────────
  - TABLE ACCESS FULL (COMMANDES)
      Most expensive step.  The entire COMMANDES table is scanned
      because EXTRACT(YEAR FROM DATECOMMANDE) cannot use a B-tree
      index on the raw DATECOMMANDE column.

  - TABLE ACCESS FULL (CLIENTS)
      Clients are fully scanned to supply the join.  With an index
      on COMMANDES(IDCLIENT) the optimiser could switch to a
      NESTED LOOP and probe CLIENTS by PK lookup instead.

  - HASH JOIN
      Reasonable for large tables but requires a memory work area.
      If memory is insufficient Oracle spills to TEMP (disk I/O).

  - SORT ORDER BY
      Required because ORDER BY NB_COMMANDES is on an aggregate,
      not on a plain indexed column.  Unavoidable unless the result
      set is small.
*/

-- =============================================================
-- Q5-d: Create indexes to improve performance
--
-- Index 1 — COMMANDES(DATECOMMANDE)
--   Eliminates the full table scan when the query is rewritten
--   with a range predicate (see "optimised query" below).
--
-- Index 2 — COMMANDES(IDCLIENT)
--   Speeds up the join: the optimiser can switch from HASH JOIN
--   to NESTED LOOPS, probing CLIENTS by its primary key index.
-- =============================================================
CREATE INDEX idx_commandes_date
    ON COMMANDES(DATECOMMANDE);

CREATE INDEX idx_commandes_idclient
    ON COMMANDES(IDCLIENT);

-- =============================================================
-- Optimised query: range predicate instead of EXTRACT
-- A range predicate lets Oracle use idx_commandes_date with an
-- INDEX RANGE SCAN, reading only the 2026 rows.
-- =============================================================
EXPLAIN PLAN SET STATEMENT_ID = 'after_index' FOR
SELECT
    c.IDCLIENT,
    c.CODECLIENT,
    c.SOCIETE,
    COUNT(cmd.IDCOMMANDE) AS NB_COMMANDES
FROM   CLIENTS c
JOIN   COMMANDES cmd ON c.IDCLIENT = cmd.IDCLIENT
WHERE  cmd.DATECOMMANDE >= DATE '2026-01-01'
AND    cmd.DATECOMMANDE <  DATE '2027-01-01'
GROUP  BY c.IDCLIENT, c.CODECLIENT, c.SOCIETE
ORDER  BY NB_COMMANDES DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    filter_preds => 'STATEMENT_ID = ''after_index'''
));

/*
  Expected improvement after indexes
  ───────────────────────────────────
  - INDEX RANGE SCAN on idx_commandes_date
      Only the rows whose DATECOMMANDE falls in 2026 are touched.

  - INDEX RANGE SCAN / NESTED LOOPS on idx_commandes_idclient
      For each qualifying COMMANDES row the optimiser can look up
      the matching CLIENTS row via its PK index rather than a
      full scan.

  - No SORT (sometimes)
      If the result set is small enough after filtering, the
      optimiser may avoid the sort pass or use a cheaper sort.
*/
