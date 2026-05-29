-- =============================================================
-- Site 1 — Fragment tables (Scenario 1, R1)
-- Criteria: IDCATEG = 50 AND QUANTITE > 100
-- All source data is fetched via synonyms pointing to the global DB.
-- =============================================================

CONNECT pdb_admin/Admin123@//localhost:1521/S1_PDB;

-- -------------------------------------------------------------
-- LIGNECOMMANDES1
-- Subset of order lines that match R1.
-- -------------------------------------------------------------
CREATE TABLE LIGNECOMMANDES1 AS
    SELECT lc.*
    FROM   LIGNECOMMANDES lc
    JOIN   PRODUITS p ON lc.IDPRODUIT = p.IDPRODUIT
    WHERE  lc.QUANTITE > 100
    AND    p.IDCATEG   = 50;

-- Primary key is not inherited from CREATE TABLE AS SELECT
ALTER TABLE LIGNECOMMANDES1
    ADD CONSTRAINT lignecommandes1_pk PRIMARY KEY (IDLIGNECOMMANDE);

-- -------------------------------------------------------------
-- PRODUITS1
-- Only the products referenced by LIGNECOMMANDES1 rows.
-- -------------------------------------------------------------
CREATE TABLE PRODUITS1 AS
    SELECT DISTINCT p.*
    FROM   PRODUITS p
    JOIN   LIGNECOMMANDES1 lc ON p.IDPRODUIT = lc.IDPRODUIT;

ALTER TABLE PRODUITS1
    ADD CONSTRAINT produits1_pk PRIMARY KEY (IDPRODUIT);

-- -------------------------------------------------------------
-- COMMANDES1
-- Only the orders referenced by LIGNECOMMANDES1 rows.
-- -------------------------------------------------------------
CREATE TABLE COMMANDES1 AS
    SELECT DISTINCT cmd.*
    FROM   COMMANDES cmd
    JOIN   LIGNECOMMANDES1 lc ON cmd.IDCOMMANDE = lc.IDCOMMANDE;

ALTER TABLE COMMANDES1
    ADD CONSTRAINT commandes1_pk PRIMARY KEY (IDCOMMANDE);

-- -------------------------------------------------------------
-- CLIENTS1
-- Only the clients who own orders in COMMANDES1.
-- -------------------------------------------------------------
CREATE TABLE CLIENTS1 AS
    SELECT DISTINCT c.*
    FROM   CLIENTS c
    JOIN   COMMANDES1 cmd ON c.IDCLIENT = cmd.IDCLIENT;

ALTER TABLE CLIENTS1
    ADD CONSTRAINT clients1_pk PRIMARY KEY (IDCLIENT);

-- -------------------------------------------------------------
-- Referential integrity constraints
-- -------------------------------------------------------------
ALTER TABLE COMMANDES1
    ADD CONSTRAINT commandes1_clients1_fk
    FOREIGN KEY (IDCLIENT) REFERENCES CLIENTS1(IDCLIENT);

ALTER TABLE LIGNECOMMANDES1
    ADD CONSTRAINT lignecommandes1_produits1_fk
    FOREIGN KEY (IDPRODUIT) REFERENCES PRODUITS1(IDPRODUIT);

ALTER TABLE LIGNECOMMANDES1
    ADD CONSTRAINT lignecommandes1_commandes1_fk
    FOREIGN KEY (IDCOMMANDE) REFERENCES COMMANDES1(IDCOMMANDE);
