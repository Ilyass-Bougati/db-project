-- =============================================================
-- Global DB — DB links to sites + synchronisation triggers (Q4)
--
-- Scenario 2 fragmentation: volume-based (Gros vs Détail)
--
--   R1 (Site 1): σ(QUANTITE >= 100)(LigneCommandes)  — gros volumes
--   R2 (Site 2): σ(QUANTITE <  100)(LigneCommandes)  — petits volumes
--
-- This is a COMPLETE partition: every row in LIGNECOMMANDES
-- belongs to exactly one of the two fragments.  No category
-- lookup is needed — QUANTITE is a direct column on the row.
-- =============================================================

-- Connect as pdb_admin so DB links are created in pdb_admin's schema.
CONNECT pdb_admin/Admin123@//localhost:1521/G_PDB

-- =============================================================
-- Database links from the global DB to each site
-- =============================================================

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
-- Routes every new LIGNECOMMANDES row to the correct fragment.
-- QUANTITE >= 100 → Site 1 (gros volumes)
-- QUANTITE <  100 → Site 2 (petits volumes)
--
-- Remote calls use EXECUTE IMMEDIATE to defer resolution to
-- runtime. Oracle 23c validates remote procedure references at
-- compile time; since the site containers start after the global,
-- a direct call would fail compilation with PLS-00352.
--
-- Because the partition is exhaustive and disjoint, exactly one
-- of the two branches always executes — no row is ever dropped
-- and no row ever goes to both sites.
-- =============================================================
CREATE OR REPLACE TRIGGER SYC_INSERT_LIGNE
AFTER INSERT ON pdb_admin.LIGNECOMMANDES
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    IF :NEW.QUANTITE >= 100 THEN
        EXECUTE IMMEDIATE 'BEGIN pdb_admin.insertligne@link_to_site1(:1,:2,:3,:4,:5); END;'
            USING :NEW.IDLIGNECOMMANDE, :NEW.IDCOMMANDE, :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE;
    ELSE
        EXECUTE IMMEDIATE 'BEGIN pdb_admin.insertligne@link_to_site2(:1,:2,:3,:4,:5); END;'
            USING :NEW.IDLIGNECOMMANDE, :NEW.IDCOMMANDE, :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20010,
            'SYC_INSERT_LIGNE: ' || SQLERRM);
END SYC_INSERT_LIGNE;
/

-- =============================================================
-- TRIGGER: SYC_DELETE_LIGNE
-- Removes the row from whichever fragment holds it.
-- =============================================================
CREATE OR REPLACE TRIGGER SYC_DELETE_LIGNE
AFTER DELETE ON pdb_admin.LIGNECOMMANDES
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    IF :OLD.QUANTITE >= 100 THEN
        EXECUTE IMMEDIATE 'BEGIN pdb_admin.deleteligne@link_to_site1(:1); END;'
            USING :OLD.IDLIGNECOMMANDE;
    ELSE
        EXECUTE IMMEDIATE 'BEGIN pdb_admin.deleteligne@link_to_site2(:1); END;'
            USING :OLD.IDLIGNECOMMANDE;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20011,
            'SYC_DELETE_LIGNE: ' || SQLERRM);
END SYC_DELETE_LIGNE;
/

-- =============================================================
-- TRIGGER: SYC_UPDATE_LIGNE
-- Handles four cases depending on whether the row crosses the
-- QUANTITE = 100 boundary before and after the update:
--
--   Old >= 100, New >= 100 → update in Site 1
--   Old >= 100, New <  100 → move from Site 1 to Site 2
--   Old <  100, New >= 100 → move from Site 2 to Site 1
--   Old <  100, New <  100 → update in Site 2
-- =============================================================
CREATE OR REPLACE TRIGGER SYC_UPDATE_LIGNE
AFTER UPDATE ON pdb_admin.LIGNECOMMANDES
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_was_s1 BOOLEAN;
    v_is_s1  BOOLEAN;
BEGIN
    v_was_s1 := (:OLD.QUANTITE >= 100);
    v_is_s1  := (:NEW.QUANTITE >= 100);

    IF v_was_s1 AND v_is_s1 THEN
        -- Row stays in Site 1
        EXECUTE IMMEDIATE 'BEGIN pdb_admin.updateligne@link_to_site1(:1,:2,:3,:4); END;'
            USING :NEW.IDLIGNECOMMANDE, :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE;
    ELSIF v_was_s1 AND NOT v_is_s1 THEN
        -- Row moves from Site 1 to Site 2
        EXECUTE IMMEDIATE 'BEGIN pdb_admin.deleteligne@link_to_site1(:1); END;'
            USING :OLD.IDLIGNECOMMANDE;
        EXECUTE IMMEDIATE 'BEGIN pdb_admin.insertligne@link_to_site2(:1,:2,:3,:4,:5); END;'
            USING :NEW.IDLIGNECOMMANDE, :NEW.IDCOMMANDE, :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE;
    ELSIF NOT v_was_s1 AND v_is_s1 THEN
        -- Row moves from Site 2 to Site 1
        EXECUTE IMMEDIATE 'BEGIN pdb_admin.deleteligne@link_to_site2(:1); END;'
            USING :OLD.IDLIGNECOMMANDE;
        EXECUTE IMMEDIATE 'BEGIN pdb_admin.insertligne@link_to_site1(:1,:2,:3,:4,:5); END;'
            USING :NEW.IDLIGNECOMMANDE, :NEW.IDCOMMANDE, :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE;
    ELSE
        -- Row stays in Site 2
        EXECUTE IMMEDIATE 'BEGIN pdb_admin.updateligne@link_to_site2(:1,:2,:3,:4); END;'
            USING :NEW.IDLIGNECOMMANDE, :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20012,
            'SYC_UPDATE_LIGNE: ' || SQLERRM);
END SYC_UPDATE_LIGNE;
/
