-- =============================================================
-- Site 1 — Fragment tables (Scenario 2, R1)
-- Criteria: QUANTITE >= 100  (gros volumes — entrepôt central)
-- Source data is fetched via synonyms pointing to the global DB.
-- =============================================================

CONNECT pdb_admin/Admin123@//localhost:1521/S1_PDB;

-- -------------------------------------------------------------
-- LIGNECOMMANDES1
-- All order lines with a quantity of 100 or more.
-- No join with PRODUITS is needed — the criterion is a direct
-- column on LIGNECOMMANDES.
-- -------------------------------------------------------------
CREATE TABLE LIGNECOMMANDES1 AS
    SELECT *
    FROM   LIGNECOMMANDES
    WHERE  QUANTITE >= 100;

ALTER TABLE LIGNECOMMANDES1
    ADD CONSTRAINT lignecommandes1_pk PRIMARY KEY (IDLIGNECOMMANDE);

-- -------------------------------------------------------------
-- PRODUITS1
-- All products referenced by at least one row in LIGNECOMMANDES1.
-- Covers every product category (not limited to a single IDCATEG).
-- -------------------------------------------------------------
CREATE TABLE PRODUITS1 AS
    SELECT DISTINCT p.*
    FROM   PRODUITS p
    JOIN   LIGNECOMMANDES1 lc ON p.IDPRODUIT = lc.IDPRODUIT;

ALTER TABLE PRODUITS1
    ADD CONSTRAINT produits1_pk PRIMARY KEY (IDPRODUIT);

-- -------------------------------------------------------------
-- COMMANDES1
-- Only the orders that contain at least one LIGNECOMMANDES1 row.
-- -------------------------------------------------------------
CREATE TABLE COMMANDES1 AS
    SELECT DISTINCT cmd.*
    FROM   COMMANDES cmd
    JOIN   LIGNECOMMANDES1 lc ON cmd.IDCOMMANDE = lc.IDCOMMANDE;

ALTER TABLE COMMANDES1
    ADD CONSTRAINT commandes1_pk PRIMARY KEY (IDCOMMANDE);

-- -------------------------------------------------------------
-- CLIENTS1
-- Only the clients who own at least one order in COMMANDES1.
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
