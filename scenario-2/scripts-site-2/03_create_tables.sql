-- =============================================================
-- Site 2 — Fragment tables (Scenario 2, R2)
-- Criteria: QUANTITE < 100  (petits volumes — magasins de proximité)
-- Source data is fetched via synonyms pointing to the global DB.
-- =============================================================

CONNECT pdb_admin/Admin123@//localhost:1521/S2_PDB;

-- -------------------------------------------------------------
-- LIGNECOMMANDES2
-- All order lines with a quantity strictly less than 100.
-- -------------------------------------------------------------
CREATE TABLE LIGNECOMMANDES2 AS
    SELECT *
    FROM   LIGNECOMMANDES
    WHERE  QUANTITE < 100;

ALTER TABLE LIGNECOMMANDES2
    ADD CONSTRAINT lignecommandes2_pk PRIMARY KEY (IDLIGNECOMMANDE);

-- -------------------------------------------------------------
-- PRODUITS2
-- All products referenced by at least one row in LIGNECOMMANDES2.
-- -------------------------------------------------------------
CREATE TABLE PRODUITS2 AS
    SELECT DISTINCT p.*
    FROM   PRODUITS p
    JOIN   LIGNECOMMANDES2 lc ON p.IDPRODUIT = lc.IDPRODUIT;

ALTER TABLE PRODUITS2
    ADD CONSTRAINT produits2_pk PRIMARY KEY (IDPRODUIT);

-- -------------------------------------------------------------
-- COMMANDES2
-- Only the orders that contain at least one LIGNECOMMANDES2 row.
-- -------------------------------------------------------------
CREATE TABLE COMMANDES2 AS
    SELECT DISTINCT cmd.*
    FROM   COMMANDES cmd
    JOIN   LIGNECOMMANDES2 lc ON cmd.IDCOMMANDE = lc.IDCOMMANDE;

ALTER TABLE COMMANDES2
    ADD CONSTRAINT commandes2_pk PRIMARY KEY (IDCOMMANDE);

-- -------------------------------------------------------------
-- CLIENTS2
-- Only the clients who own at least one order in COMMANDES2.
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
