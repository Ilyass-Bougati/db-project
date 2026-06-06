-- =============================================================
-- Global DB — DB links to sites + synchronisation triggers (Q4)
--
-- These triggers fire on every write to LIGNECOMMANDES in the
-- global DB and propagate the change to whichever site fragment
-- owns the affected row, based on the Scenario 1 criteria:
--
--   R1 (Site 1): IDCATEG = 50  AND  QUANTITE > 100
--   R2 (Site 2): IDCATEG = 35  AND  QUANTITE > 50
--
-- The category is not stored in LIGNECOMMANDES; the trigger
-- looks it up from PRODUITS using the row's IDPRODUIT.
-- =============================================================

ALTER SESSION SET CONTAINER = G_PDB;
ALTER SESSION SET CURRENT_SCHEMA = pdb_admin;

-- =============================================================
-- Database links from the global DB to each site
--
-- g_user is a dedicated cross-site connector account that exists
-- in both S1_PDB and S2_PDB.  It has CREATE SESSION and EXECUTE
-- on the insertligne / deleteligne / updateligne procedures, and
-- SELECT on the fragment tables (granted in the site procedure
-- scripts).
-- =============================================================

-- Drop existing links so this script is safe to re-run
BEGIN EXECUTE IMMEDIATE 'DROP DATABASE LINK link_to_site1'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP DATABASE LINK link_to_site2'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE DATABASE LINK link_to_site1
    CONNECT TO g_user
    IDENTIFIED BY mon_mdp
    USING 'S1_ALIAS';

CREATE DATABASE LINK link_to_site2
    CONNECT TO g_user
    IDENTIFIED BY mon_mdp
    USING 'S2_ALIAS';

-- =============================================================
-- TRIGGER: SYC_INSERT_LIGNE
-- Fires after every INSERT on LIGNECOMMANDES.
-- Routes the new row to the matching site fragment (if any).
--
-- PRAGMA AUTONOMOUS_TRANSACTION is required because the site
-- procedures issue a COMMIT.  Without it Oracle would raise
-- ORA-02089 ("COMMIT not allowed in a subordinate session")
-- when the distributed transaction spans the DB link.
--
-- Trade-off: if the global INSERT later rolls back, the site
-- already committed its copy.  In production you would use
-- Oracle Advanced Queuing or XA two-phase commit instead.
-- =============================================================
CREATE OR REPLACE TRIGGER SYC_INSERT_LIGNE
AFTER INSERT ON pdb_admin.LIGNECOMMANDES
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_idcateg PRODUITS.IDCATEG%TYPE;
BEGIN
    -- Resolve the product's category (not stored on the order line)
    SELECT IDCATEG INTO v_idcateg
    FROM   PRODUITS
    WHERE  IDPRODUIT = :NEW.IDPRODUIT;

    -- Route to Site 1 if the row matches R1
    IF v_idcateg = 50 AND :NEW.QUANTITE > 100 THEN
        pdb_admin.insertligne@link_to_site1(
            :NEW.IDLIGNECOMMANDE,
            :NEW.IDCOMMANDE,
            :NEW.IDPRODUIT,
            :NEW.QUANTITE,
            :NEW.REMISE
        );
    END IF;

    -- Route to Site 2 if the row matches R2
    IF v_idcateg = 35 AND :NEW.QUANTITE > 50 THEN
        pdb_admin.insertligne@link_to_site2(
            :NEW.IDLIGNECOMMANDE,
            :NEW.IDCOMMANDE,
            :NEW.IDPRODUIT,
            :NEW.QUANTITE,
            :NEW.REMISE
        );
    END IF;

EXCEPTION
    -- If the product is not found, the row does not belong to any fragment.
    WHEN NO_DATA_FOUND THEN NULL;
    WHEN OTHERS THEN
        -- Surface the error without crashing the main transaction.
        RAISE_APPLICATION_ERROR(-20010,
            'SYC_INSERT_LIGNE: ' || SQLERRM);
END SYC_INSERT_LIGNE;
/

-- =============================================================
-- TRIGGER: SYC_DELETE_LIGNE
-- Fires after every DELETE on LIGNECOMMANDES.
-- Removes the row from whichever site fragment held it,
-- determined by the OLD values.
-- =============================================================
CREATE OR REPLACE TRIGGER SYC_DELETE_LIGNE
AFTER DELETE ON pdb_admin.LIGNECOMMANDES
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_idcateg PRODUITS.IDCATEG%TYPE;
BEGIN
    -- Use the OLD product ID to look up its category
    SELECT IDCATEG INTO v_idcateg
    FROM   PRODUITS
    WHERE  IDPRODUIT = :OLD.IDPRODUIT;

    -- Remove from Site 1 if the deleted row matched R1
    IF v_idcateg = 50 AND :OLD.QUANTITE > 100 THEN
        pdb_admin.deleteligne@link_to_site1(:OLD.IDLIGNECOMMANDE);
    END IF;

    -- Remove from Site 2 if the deleted row matched R2
    IF v_idcateg = 35 AND :OLD.QUANTITE > 50 THEN
        pdb_admin.deleteligne@link_to_site2(:OLD.IDLIGNECOMMANDE);
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN NULL;
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20011,
            'SYC_DELETE_LIGNE: ' || SQLERRM);
END SYC_DELETE_LIGNE;
/

-- =============================================================
-- TRIGGER: SYC_UPDATE_LIGNE
-- Fires after every UPDATE on LIGNECOMMANDES.
-- Handles four cases per site by comparing fragment membership
-- before and after the change:
--
--   Old IN,  New IN  → update in place (updateligne)
--   Old IN,  New OUT → row left the fragment (deleteligne)
--   Old OUT, New IN  → row entered the fragment (insertligne)
--   Old OUT, New OUT → no action needed
-- =============================================================
CREATE OR REPLACE TRIGGER SYC_UPDATE_LIGNE
AFTER UPDATE ON pdb_admin.LIGNECOMMANDES
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_old_categ    PRODUITS.IDCATEG%TYPE;
    v_new_categ    PRODUITS.IDCATEG%TYPE;
    v_in_s1_old    BOOLEAN;
    v_in_s1_new    BOOLEAN;
    v_in_s2_old    BOOLEAN;
    v_in_s2_new    BOOLEAN;
BEGIN
    -- Resolve categories for both the old and the new product
    SELECT IDCATEG INTO v_old_categ FROM PRODUITS WHERE IDPRODUIT = :OLD.IDPRODUIT;
    SELECT IDCATEG INTO v_new_categ FROM PRODUITS WHERE IDPRODUIT = :NEW.IDPRODUIT;

    -- Determine fragment membership before and after the update
    v_in_s1_old := (v_old_categ = 50 AND :OLD.QUANTITE > 100);
    v_in_s1_new := (v_new_categ = 50 AND :NEW.QUANTITE > 100);
    v_in_s2_old := (v_old_categ = 35 AND :OLD.QUANTITE > 50);
    v_in_s2_new := (v_new_categ = 35 AND :NEW.QUANTITE > 50);

    -- ---- Site 1 ----
    IF v_in_s1_old AND v_in_s1_new THEN
        -- Row stays in Site 1: update the existing fragment row
        pdb_admin.updateligne@link_to_site1(
            :NEW.IDLIGNECOMMANDE, :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE
        );
    ELSIF v_in_s1_old AND NOT v_in_s1_new THEN
        -- Row no longer matches R1: remove it from Site 1
        pdb_admin.deleteligne@link_to_site1(:OLD.IDLIGNECOMMANDE);
    ELSIF NOT v_in_s1_old AND v_in_s1_new THEN
        -- Row now matches R1: add it to Site 1
        pdb_admin.insertligne@link_to_site1(
            :NEW.IDLIGNECOMMANDE, :NEW.IDCOMMANDE,
            :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE
        );
    END IF;

    -- ---- Site 2 ----
    IF v_in_s2_old AND v_in_s2_new THEN
        pdb_admin.updateligne@link_to_site2(
            :NEW.IDLIGNECOMMANDE, :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE
        );
    ELSIF v_in_s2_old AND NOT v_in_s2_new THEN
        pdb_admin.deleteligne@link_to_site2(:OLD.IDLIGNECOMMANDE);
    ELSIF NOT v_in_s2_old AND v_in_s2_new THEN
        pdb_admin.insertligne@link_to_site2(
            :NEW.IDLIGNECOMMANDE, :NEW.IDCOMMANDE,
            :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE
        );
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN NULL;
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20012,
            'SYC_UPDATE_LIGNE: ' || SQLERRM);
END SYC_UPDATE_LIGNE;
/
