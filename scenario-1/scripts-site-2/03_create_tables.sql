-- =============================================================
-- Site 2 — Fragment tables (Scenario 1, R2)
-- Criteria: IDCATEG = 35 AND QUANTITE > 50
-- All source data is fetched via synonyms pointing to the global DB.
-- =============================================================

CONNECT pdb_admin/Admin123@//localhost:1521/S2_PDB;

-- -------------------------------------------------------------
-- LIGNECOMMANDES2
-- Subset of order lines that match R2.
-- -------------------------------------------------------------
CREATE TABLE LIGNECOMMANDES2 AS
    SELECT lc.*
    FROM   LIGNECOMMANDES lc
    JOIN   PRODUITS p ON lc.IDPRODUIT = p.IDPRODUIT
    WHERE  lc.QUANTITE > 50
    AND    p.IDCATEG   = 35;

-- Primary key is not inherited from CREATE TABLE AS SELECT
ALTER TABLE LIGNECOMMANDES2
    ADD CONSTRAINT lignecommandes2_pk PRIMARY KEY (IDLIGNECOMMANDE);

-- -------------------------------------------------------------
-- PRODUITS2
-- Only the products referenced by LIGNECOMMANDES2 rows.
-- Must be created before the FK on LIGNECOMMANDES2 that references it.
-- -------------------------------------------------------------
CREATE TABLE PRODUITS2 AS
    SELECT DISTINCT p.*
    FROM   PRODUITS p
    JOIN   LIGNECOMMANDES2 lc ON p.IDPRODUIT = lc.IDPRODUIT;

ALTER TABLE PRODUITS2
    ADD CONSTRAINT produits2_pk PRIMARY KEY (IDPRODUIT);

-- -------------------------------------------------------------
-- COMMANDES2
-- Only the orders referenced by LIGNECOMMANDES2 rows.
-- -------------------------------------------------------------
CREATE TABLE COMMANDES2 AS
    SELECT DISTINCT cmd.*
    FROM   COMMANDES cmd
    JOIN   LIGNECOMMANDES2 lc ON cmd.IDCOMMANDE = lc.IDCOMMANDE;

ALTER TABLE COMMANDES2
    ADD CONSTRAINT commandes2_pk PRIMARY KEY (IDCOMMANDE);

-- -------------------------------------------------------------
-- CLIENTS2
-- Only the clients who own orders in COMMANDES2.
-- -------------------------------------------------------------
CREATE TABLE CLIENTS2 AS
    SELECT DISTINCT c.*
    FROM   CLIENTS c
    JOIN   COMMANDES2 cmd ON c.IDCLIENT = cmd.IDCLIENT;

ALTER TABLE CLIENTS2
    ADD CONSTRAINT clients2_pk PRIMARY KEY (IDCLIENT);

-- -------------------------------------------------------------
-- Referential integrity constraints
-- -------------------------------------------------------------
ALTER TABLE COMMANDES2
    ADD CONSTRAINT commandes2_clients2_fk
    FOREIGN KEY (IDCLIENT) REFERENCES CLIENTS2(IDCLIENT);

ALTER TABLE LIGNECOMMANDES2
    ADD CONSTRAINT lignecommandes2_produits2_fk
    FOREIGN KEY (IDPRODUIT) REFERENCES PRODUITS2(IDPRODUIT);

ALTER TABLE LIGNECOMMANDES2
    ADD CONSTRAINT lignecommandes2_commandes2_fk
    FOREIGN KEY (IDCOMMANDE) REFERENCES COMMANDES2(IDCOMMANDE);
