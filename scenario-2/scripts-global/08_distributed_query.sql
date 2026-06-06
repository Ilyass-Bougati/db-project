-- =============================================================
-- Global DB — Distributed revenue query (Q6, Scenario 2)
--
-- Calculates, for each product category, the total revenue
-- (chiffre d'affaires) achieved in 2026 by combining results
-- from both site fragments via database links.
--
-- Revenue per order line:
--   CA = QUANTITE × PRIXUNITAIRE × (1 − REMISE)
--
-- Scenario 2 is a COMPLETE partition of LIGNECOMMANDES:
--   Site 1 holds ALL rows with QUANTITE >= 100
--   Site 2 holds ALL rows with QUANTITE <  100
--
-- Together they cover every product category and every order
-- line in the global table.  UNION ALL is correct here because
-- the two fragments are disjoint by construction — deduplication
-- would be both wrong and wasteful.
-- =============================================================

ALTER SESSION SET CONTAINER = G_PDB;
ALTER SESSION SET CURRENT_SCHEMA = pdb_admin;

SELECT
    IDCATEG,
    ROUND(SUM(CA_LIGNE), 2) AS CHIFFRE_AFFAIRES_2026
FROM (

    -- ── Site 1 contribution (QUANTITE >= 100, all categories) ──
    SELECT
        p.IDCATEG,
        lc.QUANTITE * p.PRIXUNITAIRE * (1 - NVL(lc.REMISE, 0)) AS CA_LIGNE
    FROM   pdb_admin.LIGNECOMMANDES1@link_to_site1  lc
    JOIN   pdb_admin.PRODUITS1@link_to_site1         p  ON lc.IDPRODUIT  = p.IDPRODUIT
    JOIN   pdb_admin.COMMANDES1@link_to_site1        c  ON lc.IDCOMMANDE = c.IDCOMMANDE
    WHERE  c.DATECOMMANDE >= DATE '2026-01-01'
    AND    c.DATECOMMANDE <  DATE '2027-01-01'

    UNION ALL

    -- ── Site 2 contribution (QUANTITE < 100, all categories) ───
    SELECT
        p.IDCATEG,
        lc.QUANTITE * p.PRIXUNITAIRE * (1 - NVL(lc.REMISE, 0)) AS CA_LIGNE
    FROM   pdb_admin.LIGNECOMMANDES2@link_to_site2  lc
    JOIN   pdb_admin.PRODUITS2@link_to_site2         p  ON lc.IDPRODUIT  = p.IDPRODUIT
    JOIN   pdb_admin.COMMANDES2@link_to_site2        c  ON lc.IDCOMMANDE = c.IDCOMMANDE
    WHERE  c.DATECOMMANDE >= DATE '2026-01-01'
    AND    c.DATECOMMANDE <  DATE '2027-01-01'

)
GROUP  BY IDCATEG
ORDER  BY CHIFFRE_AFFAIRES_2026 DESC;

-- Sentinel queried by the healthcheck to confirm all init scripts have run.
CREATE TABLE pdb_admin.INIT_COMPLETE (sentinel VARCHAR2(20));
INSERT INTO pdb_admin.INIT_COMPLETE VALUES ('READY');
COMMIT;
GRANT SELECT ON pdb_admin.INIT_COMPLETE TO s1_user;
GRANT SELECT ON pdb_admin.INIT_COMPLETE TO s2_user;
