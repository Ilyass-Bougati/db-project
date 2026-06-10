-- =============================================================
-- Global DB — Distributed revenue query (Q6)
--
-- Calculates, for each product category, the total revenue
-- (chiffre d'affaires) achieved in 2020 by combining results
-- from both site fragments via database links.
--
-- Revenue per order line:
--   CA = QUANTITE × PRIXUNITAIRE × (1 − REMISE)
--
-- The query uses UNION ALL (not UNION) because the two fragments
-- are disjoint by design: a row in LIGNECOMMANDES1 can never
-- appear in LIGNECOMMANDES2, so deduplication would be wrong
-- and UNION ALL avoids the extra sort/hash pass that UNION needs.
-- =============================================================

ALTER SESSION SET CONTAINER = G_PDB;
ALTER SESSION SET CURRENT_SCHEMA = pdb_admin;

SELECT
    IDCATEG,
    ROUND(SUM(CA_LIGNE), 2) AS CHIFFRE_AFFAIRES_2020
FROM (

    -- ── Site 1 contribution (IDCATEG=50, QUANTITE>100) ──────
    SELECT
        p.IDCATEG,
        lc.QUANTITE * p.PRIXUNITAIRE * (1 - NVL(lc.REMISE, 0)) AS CA_LIGNE
    FROM   pdb_admin.LIGNECOMMANDES1@link_to_site1  lc
    JOIN   pdb_admin.PRODUITS1@link_to_site1         p  ON lc.IDPRODUIT  = p.IDPRODUIT
    JOIN   pdb_admin.COMMANDES1@link_to_site1        c  ON lc.IDCOMMANDE = c.IDCOMMANDE
    WHERE  c.DATECOMMANDE >= DATE '2020-01-01'
    AND    c.DATECOMMANDE <  DATE '2021-01-01'

    UNION ALL

    -- ── Site 2 contribution (IDCATEG=35, QUANTITE>50) ───────
    SELECT
        p.IDCATEG,
        lc.QUANTITE * p.PRIXUNITAIRE * (1 - NVL(lc.REMISE, 0)) AS CA_LIGNE
    FROM   pdb_admin.LIGNECOMMANDES2@link_to_site2  lc
    JOIN   pdb_admin.PRODUITS2@link_to_site2         p  ON lc.IDPRODUIT  = p.IDPRODUIT
    JOIN   pdb_admin.COMMANDES2@link_to_site2        c  ON lc.IDCOMMANDE = c.IDCOMMANDE
    WHERE  c.DATECOMMANDE >= DATE '2020-01-01'
    AND    c.DATECOMMANDE <  DATE '2021-01-01'

)
GROUP  BY IDCATEG
ORDER  BY CHIFFRE_AFFAIRES_2020 DESC;

-- Sentinel queried by the healthcheck to confirm all init scripts have run.
-- Site containers depend on this being present before they start.
CREATE TABLE pdb_admin.INIT_COMPLETE (sentinel VARCHAR2(20));
INSERT INTO pdb_admin.INIT_COMPLETE VALUES ('READY');
COMMIT;
GRANT SELECT ON pdb_admin.INIT_COMPLETE TO s1_user;
GRANT SELECT ON pdb_admin.INIT_COMPLETE TO s2_user;
