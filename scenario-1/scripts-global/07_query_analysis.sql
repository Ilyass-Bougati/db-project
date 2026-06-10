-- =============================================================
-- Global DB — Query analysis and index optimisation (Q5)
-- Schema scale: ~1 000 CLIENTS, ~10 000 COMMANDES
-- =============================================================

ALTER SESSION SET CONTAINER = G_PDB;
ALTER SESSION SET CURRENT_SCHEMA = pdb_admin;

-- =============================================================
-- Q5-a: Number of orders per client in 2026
--
-- Note: EXTRACT(YEAR FROM DATECOMMANDE) is NON-SARGABLE — a
-- plain B-tree index on DATECOMMANDE stores raw DATE values,
-- so the optimiser cannot navigate it to satisfy a predicate
-- on a derived (function) value.  This version forces a full
-- scan regardless of any index on the column.
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
-- Expected operations:
--   TABLE ACCESS FULL on COMMANDES  → every row read to apply
--                                     the EXTRACT filter
--   TABLE ACCESS FULL on CLIENTS    → every row read for the join
--   HASH JOIN                       → two full scans hashed in memory
--   SORT ORDER BY                   → extra pass, ORDER BY is on an
--                                     aggregate so no index can help
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
SELECT plan_table_output
FROM   TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'before_index', 'TYPICAL'));

/*
  Analysis — before indexes
  ─────────────────────────
  - TABLE ACCESS FULL (COMMANDES)
      The whole table is scanned.  Even if an index existed on
      DATECOMMANDE it would be unusable here: the predicate is on
      EXTRACT(YEAR FROM DATECOMMANDE), a value the index does not
      contain.

  - TABLE ACCESS FULL (CLIENTS)
      All clients are read to feed the join.

  - HASH JOIN
      Sensible default for two full scans; needs a memory work
      area and spills to TEMP if memory is insufficient.

  - SORT ORDER BY
      ORDER BY is on COUNT(*), an aggregate computed at run time,
      so no index can ever remove this step.

  IMPORTANT — scale caveat
      At ~10 000 rows, COMMANDES occupies only a few hundred 8 KB
      blocks.  A full scan reads them with multiblock I/O in
      milliseconds (and from the buffer cache after the first run).
      The improvement we demonstrate below is therefore measured in
      LOGICAL WORK (plan cost, blocks touched), not wall-clock time.
      The plan shape is what generalises: at 50M rows the same full
      scan would take tens of seconds while the indexed plan stays
      in milliseconds.
*/

-- =============================================================
-- Q5-d: Create indexes to improve performance
--
-- Index 1 — COMMANDES(DATECOMMANDE)
--   Useless against the EXTRACT version of the query (predicate
--   shape does not match the indexed values).  It only pays off
--   once the query is rewritten with a sargable range predicate
--   (see optimised query below).
--
-- Index 2 — COMMANDES(IDCLIENT)
--   Helps with NO query change: the join condition is already
--   sargable.  Lets the optimiser consider NESTED LOOPS, probing
--   CLIENTS through its primary-key index.
-- =============================================================
CREATE INDEX idx_commandes_date
    ON COMMANDES(DATECOMMANDE);

CREATE INDEX idx_commandes_idclient
    ON COMMANDES(IDCLIENT);

-- Refresh optimiser statistics so the cost comparison is honest.
-- Without fresh stats the optimiser may misestimate cardinalities
-- and the before/after plans are not comparable.
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'COMMANDES', cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'CLIENTS',   cascade => TRUE);
END;
/

-- =============================================================
-- Optimised query: SARGABLE range predicate instead of EXTRACT
--
-- Same logical result set, but the filter is now a direct range
-- over the raw DATE values stored in idx_commandes_date, so the
-- optimiser can descend the B-tree to 2026-01-01 and walk the
-- leaf blocks until the end of the year (INDEX RANGE SCAN).
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

SELECT plan_table_output
FROM   TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'after_index', 'TYPICAL'));

/*
  Analysis — after indexes
  ────────────────────────
  - INDEX RANGE SCAN on idx_commandes_date (expected if 2026 is
    selective): only the blocks holding 2026 rows are touched.

  - NESTED LOOPS via idx_commandes_idclient / CLIENTS PK: each
    qualifying order probes its client by index lookup instead of
    contributing to a full-scan hash join.

  - SORT ORDER BY remains: it sorts on an aggregate and is
    unavoidable, but it now operates on fewer rows.

  Caveat — the optimiser may IGNORE the indexes, and be right
  ───────────────────────────────────────────────────────────
  If 2026 covers a large fraction of the 10 000 orders, an index
  range scan + thousands of single-block table accesses by ROWID
  costs MORE than one multiblock full scan.  The optimiser's cost
  model knows this; an unchanged plan is correct behaviour, not a
  failure.  To make the index visibly win, use a more selective
  predicate, e.g. one month:
      WHERE cmd.DATECOMMANDE >= DATE '2026-01-01'
      AND   cmd.DATECOMMANDE <  DATE '2026-02-01'
*/

-- =============================================================
-- Measuring the gain honestly: logical I/O, not wall-clock time
--
-- In SQL*Plus / SQLcl, compare "consistent gets" between the two
-- queries.  Blocks touched is the metric that scales with table
-- size; elapsed time at 10k rows is noise.
-- =============================================================
SET AUTOTRACE TRACEONLY STATISTICS

-- Run 1: original non-sargable query (full scan path)
SELECT c.IDCLIENT, c.CODECLIENT, c.SOCIETE,
       COUNT(cmd.IDCOMMANDE) AS NB_COMMANDES
FROM   CLIENTS c
JOIN   COMMANDES cmd ON c.IDCLIENT = cmd.IDCLIENT
WHERE  EXTRACT(YEAR FROM cmd.DATECOMMANDE) = 2026
GROUP  BY c.IDCLIENT, c.CODECLIENT, c.SOCIETE
ORDER  BY NB_COMMANDES DESC;

-- Run 2: rewritten sargable query (index path)
SELECT c.IDCLIENT, c.CODECLIENT, c.SOCIETE,
       COUNT(cmd.IDCOMMANDE) AS NB_COMMANDES
FROM   CLIENTS c
JOIN   COMMANDES cmd ON c.IDCLIENT = cmd.IDCLIENT
WHERE  cmd.DATECOMMANDE >= DATE '2026-01-01'
AND    cmd.DATECOMMANDE <  DATE '2027-01-01'
GROUP  BY c.IDCLIENT, c.CODECLIENT, c.SOCIETE
ORDER  BY NB_COMMANDES DESC;

SET AUTOTRACE OFF

-- =============================================================
-- Alternative when the query CANNOT be rewritten
-- (e.g. SQL generated by an ORM or buried in a view):
-- a FUNCTION-BASED INDEX stores the derived value itself, so the
-- original EXTRACT predicate becomes sargable as-is.
-- =============================================================
-- CREATE INDEX idx_commandes_annee
--     ON COMMANDES (EXTRACT(YEAR FROM DATECOMMANDE));
--
-- Requires QUERY_REWRITE_ENABLED = TRUE (default in modern
-- versions) and fresh statistics on the index.

/*
  Conclusion
  ──────────
  1. CREATE INDEX is not a magic go-faster button: the predicate
     shape must match the indexed values (sargability).  Either
     rewrite the query to fit the index, or build a function-based
     index to fit the query.
  2. idx_commandes_idclient improves the join with no rewrite;
     idx_commandes_date requires the range-predicate rewrite.
  3. At this scale (1k clients / 10k orders) the gain is invisible
     in elapsed time; it is demonstrated through plan cost and
     consistent gets, which are the quantities that scale.
*/
