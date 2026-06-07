# Test Plan — Distributed Oracle DB

## Architecture Summary

| Node | PDB | Scenario 1 port | Scenario 2 port |
|------|-----|-----------------|-----------------|
| Global | G_PDB | 1521 | 1531 |
| Site 1 | S1_PDB | 1522 | 1532 |
| Site 2 | S2_PDB | — (commented out) | 1533 |

**Credentials:** `pdb_admin / Admin123`

Connect with: `sqlplus pdb_admin/Admin123@//localhost:<port>/<PDB>`

---

## Scenario 1 — Category-based fragmentation (partial)

### Fragmentation rules

| Fragment | Location | Criteria |
|----------|----------|----------|
| R1 | Site 1 — `LIGNECOMMANDES1` | `IDCATEG = 50` AND `QUANTITE > 100` |
| R2 | Site 2 — `LIGNECOMMANDES2` | `IDCATEG = 35` AND `QUANTITE > 50` |
| (none) | Global only | Everything else |

> R1 and R2 are **disjoint but not exhaustive**: rows matching neither criterion exist only in the global table.

---

### S1-T1 — Verify initial fragmentation counts

Run on **global (port 1521)**:

```sql
-- Count rows that should be in Site 1
SELECT COUNT(*) AS expected_s1
FROM   pdb_admin.LIGNECOMMANDES lc
JOIN   pdb_admin.PRODUITS p ON lc.IDPRODUIT = p.IDPRODUIT
WHERE  p.IDCATEG = 50
AND    lc.QUANTITE > 100;

-- Count rows that should be in Site 2
SELECT COUNT(*) AS expected_s2
FROM   pdb_admin.LIGNECOMMANDES lc
JOIN   pdb_admin.PRODUITS p ON lc.IDPRODUIT = p.IDPRODUIT
WHERE  p.IDCATEG = 35
AND    lc.QUANTITE > 50;
```

Run on **Site 1 (port 1522)**:

```sql
SELECT COUNT(*) AS actual_s1 FROM pdb_admin.LIGNECOMMANDES1;
```

Run on **Site 2 (port 1523)**:

```sql
SELECT COUNT(*) AS actual_s2 FROM pdb_admin.LIGNECOMMANDES2;
```

**Expected:** `actual_s1 = expected_s1` and `actual_s2 = expected_s2`.

---

### S1-T2 — INSERT routed to Site 1 (matches R1)

**Step 1 — Find valid parent IDs** (run on **global**):

```sql
-- A product in category 50 that already has rows in Site 1
SELECT IDPRODUIT FROM (
    SELECT DISTINCT lc.IDPRODUIT
    FROM   pdb_admin.LIGNECOMMANDES lc
    JOIN   pdb_admin.PRODUITS p ON lc.IDPRODUIT = p.IDPRODUIT
    WHERE  p.IDCATEG = 50 AND lc.QUANTITE > 100
    ORDER  BY 1
) WHERE ROWNUM = 1;

-- An order that is already in Site 1's fragment
SELECT IDCOMMANDE FROM (
    SELECT DISTINCT lc.IDCOMMANDE
    FROM   pdb_admin.LIGNECOMMANDES lc
    JOIN   pdb_admin.PRODUITS p ON lc.IDPRODUIT = p.IDPRODUIT
    WHERE  p.IDCATEG = 50 AND lc.QUANTITE > 100
    ORDER  BY 1
) WHERE ROWNUM = 1;
```

**Step 2 — Insert on global** (replace `<IDPRODUIT>` and `<IDCOMMANDE>` with values from above):

```sql
INSERT INTO pdb_admin.LIGNECOMMANDES (IDLIGNECOMMANDE, IDCOMMANDE, IDPRODUIT, QUANTITE, REMISE)
VALUES (99001, <IDCOMMANDE>, <IDPRODUIT>, 150, 0);
COMMIT;
```

**Step 3 — Verify on Site 1 (port 1522)**:

```sql
SELECT * FROM pdb_admin.LIGNECOMMANDES1 WHERE IDLIGNECOMMANDE = 99001;
-- Expected: 1 row with QUANTITE=150
```

**Step 4 — Confirm NOT on Site 2 (port 1523)**:

```sql
SELECT COUNT(*) FROM pdb_admin.LIGNECOMMANDES2 WHERE IDLIGNECOMMANDE = 99001;
-- Expected: 0
```

---

### S1-T3 — INSERT routed to Site 2 (matches R2)

**Step 1 — Find valid parent IDs** (run on **global**):

```sql
SELECT IDPRODUIT FROM (
    SELECT DISTINCT lc.IDPRODUIT
    FROM   pdb_admin.LIGNECOMMANDES lc
    JOIN   pdb_admin.PRODUITS p ON lc.IDPRODUIT = p.IDPRODUIT
    WHERE  p.IDCATEG = 35 AND lc.QUANTITE > 50
    ORDER  BY 1
) WHERE ROWNUM = 1;

SELECT IDCOMMANDE FROM (
    SELECT DISTINCT lc.IDCOMMANDE
    FROM   pdb_admin.LIGNECOMMANDES lc
    JOIN   pdb_admin.PRODUITS p ON lc.IDPRODUIT = p.IDPRODUIT
    WHERE  p.IDCATEG = 35 AND lc.QUANTITE > 50
    ORDER  BY 1
) WHERE ROWNUM = 1;
```

**Step 2 — Insert on global**:

```sql
INSERT INTO pdb_admin.LIGNECOMMANDES (IDLIGNECOMMANDE, IDCOMMANDE, IDPRODUIT, QUANTITE, REMISE)
VALUES (99002, <IDCOMMANDE>, <IDPRODUIT>, 75, 0);
COMMIT;
```

**Step 3 — Verify on Site 2 (port 1523)**:

```sql
SELECT * FROM pdb_admin.LIGNECOMMANDES2 WHERE IDLIGNECOMMANDE = 99002;
-- Expected: 1 row with QUANTITE=75
```

**Step 4 — Confirm NOT on Site 1 (port 1522)**:

```sql
SELECT COUNT(*) FROM pdb_admin.LIGNECOMMANDES1 WHERE IDLIGNECOMMANDE = 99002;
-- Expected: 0
```

---

### S1-T4 — INSERT that matches neither fragment (stays global only)

Use a product with `IDCATEG` other than 35 or 50.

**Step 1 — Find a product in a different category** (run on **global**):

```sql
SELECT IDPRODUIT, IDCATEG FROM (
    SELECT IDPRODUIT, IDCATEG
    FROM   pdb_admin.PRODUITS
    WHERE  IDCATEG NOT IN (35, 50)
    ORDER  BY 1
) WHERE ROWNUM = 1;

-- Any COMMANDES row will do
SELECT IDCOMMANDE FROM pdb_admin.COMMANDES WHERE ROWNUM = 1;
```

**Step 2 — Insert on global**:

```sql
INSERT INTO pdb_admin.LIGNECOMMANDES (IDLIGNECOMMANDE, IDCOMMANDE, IDPRODUIT, QUANTITE, REMISE)
VALUES (99003, <IDCOMMANDE>, <IDPRODUIT>, 200, 0);
COMMIT;
```

**Step 3 — Verify present on global**:

```sql
SELECT * FROM pdb_admin.LIGNECOMMANDES WHERE IDLIGNECOMMANDE = 99003;
-- Expected: 1 row
```

**Step 4 — Verify absent from both sites**:

```sql
-- Site 1 (port 1522)
SELECT COUNT(*) FROM pdb_admin.LIGNECOMMANDES1 WHERE IDLIGNECOMMANDE = 99003;
-- Expected: 0

-- Site 2 (port 1523)
SELECT COUNT(*) FROM pdb_admin.LIGNECOMMANDES2 WHERE IDLIGNECOMMANDE = 99003;
-- Expected: 0
```

---

### S1-T5 — Boundary values (off-by-one on QUANTITE)

These use the same parent IDs from T2 (category 50 product, category 50 order).

**QUANTITE = 100 exactly — must NOT go to Site 1 (R1 requires `> 100`)**

```sql
-- On global:
INSERT INTO pdb_admin.LIGNECOMMANDES (IDLIGNECOMMANDE, IDCOMMANDE, IDPRODUIT, QUANTITE, REMISE)
VALUES (99004, <IDCOMMANDE_cat50>, <IDPRODUIT_cat50>, 100, 0);
COMMIT;

-- On Site 1 (port 1522):
SELECT COUNT(*) FROM pdb_admin.LIGNECOMMANDES1 WHERE IDLIGNECOMMANDE = 99004;
-- Expected: 0  (100 is not > 100)
```

**QUANTITE = 101 exactly — must go to Site 1**

```sql
-- On global:
INSERT INTO pdb_admin.LIGNECOMMANDES (IDLIGNECOMMANDE, IDCOMMANDE, IDPRODUIT, QUANTITE, REMISE)
VALUES (99005, <IDCOMMANDE_cat50>, <IDPRODUIT_cat50>, 101, 0);
COMMIT;

-- On Site 1 (port 1522):
SELECT COUNT(*) FROM pdb_admin.LIGNECOMMANDES1 WHERE IDLIGNECOMMANDE = 99005;
-- Expected: 1
```

Similarly for R2 (category 35, threshold 50):

```sql
-- QUANTITE = 50 — must NOT go to Site 2
INSERT INTO pdb_admin.LIGNECOMMANDES (IDLIGNECOMMANDE, IDCOMMANDE, IDPRODUIT, QUANTITE, REMISE)
VALUES (99006, <IDCOMMANDE_cat35>, <IDPRODUIT_cat35>, 50, 0);
COMMIT;

-- On Site 2 (port 1523):
SELECT COUNT(*) FROM pdb_admin.LIGNECOMMANDES2 WHERE IDLIGNECOMMANDE = 99006;
-- Expected: 0

-- QUANTITE = 51 — must go to Site 2
INSERT INTO pdb_admin.LIGNECOMMANDES (IDLIGNECOMMANDE, IDCOMMANDE, IDPRODUIT, QUANTITE, REMISE)
VALUES (99007, <IDCOMMANDE_cat35>, <IDPRODUIT_cat35>, 51, 0);
COMMIT;

-- On Site 2 (port 1523):
SELECT COUNT(*) FROM pdb_admin.LIGNECOMMANDES2 WHERE IDLIGNECOMMANDE = 99007;
-- Expected: 1
```

---

### S1-T6 — DELETE propagates to site

Uses row 99001 inserted in T2 (which lives on Site 1).

**On global**:

```sql
DELETE FROM pdb_admin.LIGNECOMMANDES WHERE IDLIGNECOMMANDE = 99001;
COMMIT;
```

**Verify on Site 1 (port 1522)**:

```sql
SELECT COUNT(*) FROM pdb_admin.LIGNECOMMANDES1 WHERE IDLIGNECOMMANDE = 99001;
-- Expected: 0 — trigger called deleteligne@link_to_site1

SELECT COUNT(*) FROM pdb_admin.LIGNECOMMANDES1;
-- Expected: same count as before T2 (net zero change)
```

---

### S1-T7 — UPDATE keeps row in same site (QUANTITE drops but stays above threshold)

Uses row 99005 (category 50, QUANTITE=101, currently on Site 1).

**On global**:

```sql
UPDATE pdb_admin.LIGNECOMMANDES SET QUANTITE = 120 WHERE IDLIGNECOMMANDE = 99005;
COMMIT;
```

**Verify on Site 1 (port 1522)**:

```sql
SELECT QUANTITE FROM pdb_admin.LIGNECOMMANDES1 WHERE IDLIGNECOMMANDE = 99005;
-- Expected: 120 — trigger called updateligne@link_to_site1
```

---

### S1-T8 — UPDATE crosses fragment boundary (QUANTITE drops below threshold)

Row 99005 is currently on Site 1 (category 50, QUANTITE=120). Dropping QUANTITE to 50 means it no longer matches R1, so it must be deleted from Site 1.

**On global**:

```sql
UPDATE pdb_admin.LIGNECOMMANDES SET QUANTITE = 50 WHERE IDLIGNECOMMANDE = 99005;
COMMIT;
```

**Verify removed from Site 1 (port 1522)**:

```sql
SELECT COUNT(*) FROM pdb_admin.LIGNECOMMANDES1 WHERE IDLIGNECOMMANDE = 99005;
-- Expected: 0 — trigger called deleteligne@link_to_site1
```

**Verify NOT added to Site 2** (IDCATEG=50, not 35, so it doesn't match R2 either):

```sql
SELECT COUNT(*) FROM pdb_admin.LIGNECOMMANDES2 WHERE IDLIGNECOMMANDE = 99005;
-- Expected: 0
```

**Verify still in global**:

```sql
SELECT QUANTITE FROM pdb_admin.LIGNECOMMANDES WHERE IDLIGNECOMMANDE = 99005;
-- Expected: 1 row, QUANTITE=50
```

---

### S1-T9 — Distributed revenue query (Q6)

Run on **global (port 1521)**:

```sql
SELECT
    IDCATEG,
    ROUND(SUM(CA_LIGNE), 2) AS CHIFFRE_AFFAIRES_2026
FROM (
    SELECT p.IDCATEG,
           lc.QUANTITE * p.PRIXUNITAIRE * (1 - NVL(lc.REMISE, 0)) AS CA_LIGNE
    FROM   pdb_admin.LIGNECOMMANDES1@link_to_site1 lc
    JOIN   pdb_admin.PRODUITS1@link_to_site1        p  ON lc.IDPRODUIT  = p.IDPRODUIT
    JOIN   pdb_admin.COMMANDES1@link_to_site1       c  ON lc.IDCOMMANDE = c.IDCOMMANDE
    WHERE  c.DATECOMMANDE >= DATE '2026-01-01'
    AND    c.DATECOMMANDE <  DATE '2027-01-01'

    UNION ALL

    SELECT p.IDCATEG,
           lc.QUANTITE * p.PRIXUNITAIRE * (1 - NVL(lc.REMISE, 0)) AS CA_LIGNE
    FROM   pdb_admin.LIGNECOMMANDES2@link_to_site2 lc
    JOIN   pdb_admin.PRODUITS2@link_to_site2        p  ON lc.IDPRODUIT  = p.IDPRODUIT
    JOIN   pdb_admin.COMMANDES2@link_to_site2       c  ON lc.IDCOMMANDE = c.IDCOMMANDE
    WHERE  c.DATECOMMANDE >= DATE '2026-01-01'
    AND    c.DATECOMMANDE <  DATE '2027-01-01'
)
GROUP  BY IDCATEG
ORDER  BY CHIFFRE_AFFAIRES_2026 DESC;
```

**Expected:** Results show only two IDCATEG values (50 and 35), since the fragments are category-filtered. The query must return without ORA- errors, confirming both DB links are alive.

---

### S1 Cleanup

Run on **global** to remove all test rows:

```sql
DELETE FROM pdb_admin.LIGNECOMMANDES
WHERE IDLIGNECOMMANDE IN (99002, 99003, 99004, 99006, 99007);
COMMIT;
-- 99001 and 99005 were already deleted by T6 and T8.
```

---

---

## Scenario 2 — Volume-based fragmentation (complete partition)

### Fragmentation rules

| Fragment | Location | Criteria |
|----------|----------|----------|
| R1 | Site 1 — `LIGNECOMMANDES1` | `QUANTITE >= 100` (all categories) |
| R2 | Site 2 — `LIGNECOMMANDES2` | `QUANTITE < 100` (all categories) |

> This is a **complete partition**: every row in LIGNECOMMANDES belongs to exactly one site. No row stays global only.

---

### S2-T1 — Verify initial fragmentation counts

Run on **global (port 1531)**:

```sql
SELECT COUNT(*) AS global_total      FROM pdb_admin.LIGNECOMMANDES;
SELECT COUNT(*) AS expected_s1       FROM pdb_admin.LIGNECOMMANDES WHERE QUANTITE >= 100;
SELECT COUNT(*) AS expected_s2       FROM pdb_admin.LIGNECOMMANDES WHERE QUANTITE <  100;
```

Run on **Site 1 (port 1532)**:

```sql
SELECT COUNT(*) AS actual_s1 FROM pdb_admin.LIGNECOMMANDES1;
```

Run on **Site 2 (port 1533)**:

```sql
SELECT COUNT(*) AS actual_s2 FROM pdb_admin.LIGNECOMMANDES2;
```

**Expected:**
- `actual_s1 = expected_s1`
- `actual_s2 = expected_s2`
- `actual_s1 + actual_s2 = global_total` (complete partition — no row is dropped)

---

### S2-T2 — INSERT with QUANTITE >= 100 routes to Site 1

**Step 1 — Find valid parent IDs** (run on **global**):

```sql
-- Any order already in Site 1's fragment
SELECT IDCOMMANDE FROM (
    SELECT DISTINCT IDCOMMANDE FROM pdb_admin.COMMANDES
    WHERE  IDCOMMANDE IN (SELECT IDCOMMANDE FROM pdb_admin.LIGNECOMMANDES WHERE QUANTITE >= 100)
    ORDER  BY 1
) WHERE ROWNUM = 1;

-- Any product already in Site 1's fragment
SELECT IDPRODUIT FROM (
    SELECT DISTINCT IDPRODUIT FROM pdb_admin.LIGNECOMMANDES WHERE QUANTITE >= 100
    ORDER  BY 1
) WHERE ROWNUM = 1;
```

**Step 2 — Insert on global (port 1531)**:

```sql
INSERT INTO pdb_admin.LIGNECOMMANDES (IDLIGNECOMMANDE, IDCOMMANDE, IDPRODUIT, QUANTITE, REMISE)
VALUES (99011, <IDCOMMANDE>, <IDPRODUIT>, 150, 0);
COMMIT;
```

**Step 3 — Verify on Site 1 (port 1532)**:

```sql
SELECT * FROM pdb_admin.LIGNECOMMANDES1 WHERE IDLIGNECOMMANDE = 99011;
-- Expected: 1 row with QUANTITE=150
```

**Step 4 — Confirm NOT on Site 2 (port 1533)**:

```sql
SELECT COUNT(*) FROM pdb_admin.LIGNECOMMANDES2 WHERE IDLIGNECOMMANDE = 99011;
-- Expected: 0
```

---

### S2-T3 — INSERT with QUANTITE < 100 routes to Site 2

**Step 1 — Find valid parent IDs** (run on **global**):

```sql
SELECT IDCOMMANDE FROM (
    SELECT DISTINCT IDCOMMANDE FROM pdb_admin.COMMANDES
    WHERE  IDCOMMANDE IN (SELECT IDCOMMANDE FROM pdb_admin.LIGNECOMMANDES WHERE QUANTITE < 100)
    ORDER  BY 1
) WHERE ROWNUM = 1;

SELECT IDPRODUIT FROM (
    SELECT DISTINCT IDPRODUIT FROM pdb_admin.LIGNECOMMANDES WHERE QUANTITE < 100
    ORDER  BY 1
) WHERE ROWNUM = 1;
```

**Step 2 — Insert on global**:

```sql
INSERT INTO pdb_admin.LIGNECOMMANDES (IDLIGNECOMMANDE, IDCOMMANDE, IDPRODUIT, QUANTITE, REMISE)
VALUES (99012, <IDCOMMANDE>, <IDPRODUIT>, 50, 0);
COMMIT;
```

**Step 3 — Verify on Site 2 (port 1533)**:

```sql
SELECT * FROM pdb_admin.LIGNECOMMANDES2 WHERE IDLIGNECOMMANDE = 99012;
-- Expected: 1 row with QUANTITE=50
```

**Step 4 — Confirm NOT on Site 1 (port 1532)**:

```sql
SELECT COUNT(*) FROM pdb_admin.LIGNECOMMANDES1 WHERE IDLIGNECOMMANDE = 99012;
-- Expected: 0
```

---

### S2-T4 — Boundary: QUANTITE = 100 goes to Site 1 (>= 100)

```sql
-- On global:
INSERT INTO pdb_admin.LIGNECOMMANDES (IDLIGNECOMMANDE, IDCOMMANDE, IDPRODUIT, QUANTITE, REMISE)
VALUES (99013, <IDCOMMANDE_s1>, <IDPRODUIT_s1>, 100, 0);
COMMIT;

-- On Site 1 (port 1532):
SELECT COUNT(*) FROM pdb_admin.LIGNECOMMANDES1 WHERE IDLIGNECOMMANDE = 99013;
-- Expected: 1

-- On Site 2 (port 1533):
SELECT COUNT(*) FROM pdb_admin.LIGNECOMMANDES2 WHERE IDLIGNECOMMANDE = 99013;
-- Expected: 0
```

---

### S2-T5 — Boundary: QUANTITE = 99 goes to Site 2 (< 100)

```sql
-- On global:
INSERT INTO pdb_admin.LIGNECOMMANDES (IDLIGNECOMMANDE, IDCOMMANDE, IDPRODUIT, QUANTITE, REMISE)
VALUES (99014, <IDCOMMANDE_s2>, <IDPRODUIT_s2>, 99, 0);
COMMIT;

-- On Site 2 (port 1533):
SELECT COUNT(*) FROM pdb_admin.LIGNECOMMANDES2 WHERE IDLIGNECOMMANDE = 99014;
-- Expected: 1

-- On Site 1 (port 1532):
SELECT COUNT(*) FROM pdb_admin.LIGNECOMMANDES1 WHERE IDLIGNECOMMANDE = 99014;
-- Expected: 0
```

---

### S2-T6 — DELETE propagates to correct site

Uses row 99011 (on Site 1, QUANTITE=150).

**On global**:

```sql
DELETE FROM pdb_admin.LIGNECOMMANDES WHERE IDLIGNECOMMANDE = 99011;
COMMIT;
```

**Verify on Site 1 (port 1532)**:

```sql
SELECT COUNT(*) FROM pdb_admin.LIGNECOMMANDES1 WHERE IDLIGNECOMMANDE = 99011;
-- Expected: 0
```

---

### S2-T7 — UPDATE crosses the QUANTITE = 100 boundary (Site 1 → Site 2)

Uses row 99013 (currently on Site 1, QUANTITE=100). Dropping to 99 moves it to Site 2.

**On global**:

```sql
UPDATE pdb_admin.LIGNECOMMANDES SET QUANTITE = 99 WHERE IDLIGNECOMMANDE = 99013;
COMMIT;
```

**Verify removed from Site 1 (port 1532)**:

```sql
SELECT COUNT(*) FROM pdb_admin.LIGNECOMMANDES1 WHERE IDLIGNECOMMANDE = 99013;
-- Expected: 0 — trigger called deleteligne@link_to_site1, then insertligne@link_to_site2
```

**Verify now on Site 2 (port 1533)**:

```sql
SELECT QUANTITE FROM pdb_admin.LIGNECOMMANDES2 WHERE IDLIGNECOMMANDE = 99013;
-- Expected: 1 row, QUANTITE=99
```

---

### S2-T8 — UPDATE crosses the QUANTITE = 100 boundary (Site 2 → Site 1)

Uses row 99014 (currently on Site 2, QUANTITE=99). Raising to 100 moves it to Site 1.

**On global**:

```sql
UPDATE pdb_admin.LIGNECOMMANDES SET QUANTITE = 100 WHERE IDLIGNECOMMANDE = 99014;
COMMIT;
```

**Verify removed from Site 2 (port 1533)**:

```sql
SELECT COUNT(*) FROM pdb_admin.LIGNECOMMANDES2 WHERE IDLIGNECOMMANDE = 99014;
-- Expected: 0
```

**Verify now on Site 1 (port 1532)**:

```sql
SELECT QUANTITE FROM pdb_admin.LIGNECOMMANDES1 WHERE IDLIGNECOMMANDE = 99014;
-- Expected: 1 row, QUANTITE=100
```

---

### S2-T9 — Distributed revenue query (Q6)

Run on **global (port 1531)**:

```sql
SELECT
    IDCATEG,
    ROUND(SUM(CA_LIGNE), 2) AS CHIFFRE_AFFAIRES_2026
FROM (
    SELECT p.IDCATEG,
           lc.QUANTITE * p.PRIXUNITAIRE * (1 - NVL(lc.REMISE, 0)) AS CA_LIGNE
    FROM   pdb_admin.LIGNECOMMANDES1@link_to_site1 lc
    JOIN   pdb_admin.PRODUITS1@link_to_site1        p  ON lc.IDPRODUIT  = p.IDPRODUIT
    JOIN   pdb_admin.COMMANDES1@link_to_site1       c  ON lc.IDCOMMANDE = c.IDCOMMANDE
    WHERE  c.DATECOMMANDE >= DATE '2026-01-01'
    AND    c.DATECOMMANDE <  DATE '2027-01-01'

    UNION ALL

    SELECT p.IDCATEG,
           lc.QUANTITE * p.PRIXUNITAIRE * (1 - NVL(lc.REMISE, 0)) AS CA_LIGNE
    FROM   pdb_admin.LIGNECOMMANDES2@link_to_site2 lc
    JOIN   pdb_admin.PRODUITS2@link_to_site2        p  ON lc.IDPRODUIT  = p.IDPRODUIT
    JOIN   pdb_admin.COMMANDES2@link_to_site2       c  ON lc.IDCOMMANDE = c.IDCOMMANDE
    WHERE  c.DATECOMMANDE >= DATE '2026-01-01'
    AND    c.DATECOMMANDE <  DATE '2027-01-01'
)
GROUP  BY IDCATEG
ORDER  BY CHIFFRE_AFFAIRES_2026 DESC;
```

**Expected:** All product categories represented (not filtered to a subset like Scenario 1), since the partition is exhaustive. The sum over all categories from this query must equal the sum computed locally on the global table:

```sql
-- Cross-check on global:
SELECT
    p.IDCATEG,
    ROUND(SUM(lc.QUANTITE * p.PRIXUNITAIRE * (1 - NVL(lc.REMISE, 0))), 2) AS CA_LOCAL
FROM   pdb_admin.LIGNECOMMANDES lc
JOIN   pdb_admin.PRODUITS p   ON lc.IDPRODUIT  = p.IDPRODUIT
JOIN   pdb_admin.COMMANDES c  ON lc.IDCOMMANDE = c.IDCOMMANDE
WHERE  c.DATECOMMANDE >= DATE '2026-01-01'
AND    c.DATECOMMANDE <  DATE '2027-01-01'
GROUP  BY p.IDCATEG
ORDER  BY CA_LOCAL DESC;
-- Expected: identical rows to the distributed query above
```

---

### S2 Cleanup

Run on **global (port 1531)**:

```sql
DELETE FROM pdb_admin.LIGNECOMMANDES
WHERE IDLIGNECOMMANDE IN (99012, 99013, 99014);
COMMIT;
-- 99011 was already deleted by T6.
```
