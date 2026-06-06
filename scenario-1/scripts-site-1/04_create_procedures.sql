-- =============================================================
-- Site 1 — Stored procedures for LIGNECOMMANDES1 (Q2)
-- =============================================================

CONNECT pdb_admin/Admin123@//localhost:1521/S1_PDB;

-- =============================================================
-- PROCEDURE: insertligne
-- Inserts a new row into LIGNECOMMANDES1.
--
-- Before inserting, the procedure explicitly checks referential
-- integrity so that a meaningful error is raised rather than a
-- raw Oracle constraint violation.
--
-- Arguments:
--   p_idlignecommande  PK of the new order line
--   p_idcommande       Must exist in COMMANDES1
--   p_idproduit        Must exist in PRODUITS1
--   p_quantite         Ordered quantity
--   p_remise           Discount (0..1)
-- =============================================================
CREATE OR REPLACE PROCEDURE insertligne (
    p_idlignecommande IN LIGNECOMMANDES1.IDLIGNECOMMANDE%TYPE,
    p_idcommande      IN LIGNECOMMANDES1.IDCOMMANDE%TYPE,
    p_idproduit       IN LIGNECOMMANDES1.IDPRODUIT%TYPE,
    p_quantite        IN LIGNECOMMANDES1.QUANTITE%TYPE,
    p_remise          IN LIGNECOMMANDES1.REMISE%TYPE
)
IS
    v_count INTEGER;
BEGIN
    -- Verify parent order exists in this fragment
    SELECT COUNT(*) INTO v_count
    FROM   COMMANDES1
    WHERE  IDCOMMANDE = p_idcommande;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001,
            'insertligne [S1]: IDCOMMANDE=' || p_idcommande
            || ' does not exist in COMMANDES1.');
    END IF;

    -- Verify product exists in this fragment
    SELECT COUNT(*) INTO v_count
    FROM   PRODUITS1
    WHERE  IDPRODUIT = p_idproduit;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20002,
            'insertligne [S1]: IDPRODUIT=' || p_idproduit
            || ' does not exist in PRODUITS1.');
    END IF;

    INSERT INTO LIGNECOMMANDES1 (IDLIGNECOMMANDE, IDCOMMANDE, IDPRODUIT, QUANTITE, REMISE)
    VALUES (p_idlignecommande, p_idcommande, p_idproduit, p_quantite, p_remise);

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END insertligne;
/

-- =============================================================
-- PROCEDURE: deleteligne
-- Deletes a row from LIGNECOMMANDES1 by its primary key, then
-- cascades upward to remove orphaned parent rows:
--   - If the deleted line was the last one on its order
--     → delete that order from COMMANDES1
--   - If that order was the last one for its client
--     → delete that client from CLIENTS1
--
-- PRODUITS1 is NOT touched: products are master data shared
-- across many order lines.
--
-- Arguments:
--   p_idlignecommande  PK of the order line to remove
-- =============================================================
CREATE OR REPLACE PROCEDURE deleteligne (
    p_idlignecommande IN LIGNECOMMANDES1.IDLIGNECOMMANDE%TYPE
)
IS
    v_idcommande LIGNECOMMANDES1.IDCOMMANDE%TYPE;
    v_idclient   COMMANDES1.IDCLIENT%TYPE;
    v_count      INTEGER;
BEGIN
    -- Fetch parent IDs before deletion so we can do orphan checks afterward
    SELECT IDCOMMANDE INTO v_idcommande
    FROM   LIGNECOMMANDES1
    WHERE  IDLIGNECOMMANDE = p_idlignecommande;

    SELECT IDCLIENT INTO v_idclient
    FROM   COMMANDES1
    WHERE  IDCOMMANDE = v_idcommande;

    -- Delete the target line
    DELETE FROM LIGNECOMMANDES1
    WHERE  IDLIGNECOMMANDE = p_idlignecommande;

    -- Check if the parent order now has no remaining lines
    SELECT COUNT(*) INTO v_count
    FROM   LIGNECOMMANDES1
    WHERE  IDCOMMANDE = v_idcommande;

    IF v_count = 0 THEN
        DELETE FROM COMMANDES1 WHERE IDCOMMANDE = v_idcommande;

        -- Check if the parent client now has no remaining orders
        SELECT COUNT(*) INTO v_count
        FROM   COMMANDES1
        WHERE  IDCLIENT = v_idclient;

        IF v_count = 0 THEN
            DELETE FROM CLIENTS1 WHERE IDCLIENT = v_idclient;
        END IF;
    END IF;

    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20003,
            'deleteligne [S1]: IDLIGNECOMMANDE=' || p_idlignecommande
            || ' does not exist in LIGNECOMMANDES1.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END deleteligne;
/

-- =============================================================
-- PROCEDURE: updateligne
-- Updates IDPRODUIT, QUANTITE, and REMISE for an existing row
-- in LIGNECOMMANDES1.  Only these three columns are in scope
-- per the project specification.
--
-- Arguments:
--   p_idlignecommande  PK of the line to update
--   p_idproduit        New product (must exist in PRODUITS1)
--   p_quantite         New quantity
--   p_remise           New discount (0..1)
-- =============================================================
CREATE OR REPLACE PROCEDURE updateligne (
    p_idlignecommande IN LIGNECOMMANDES1.IDLIGNECOMMANDE%TYPE,
    p_idproduit       IN LIGNECOMMANDES1.IDPRODUIT%TYPE,
    p_quantite        IN LIGNECOMMANDES1.QUANTITE%TYPE,
    p_remise          IN LIGNECOMMANDES1.REMISE%TYPE
)
IS
    v_count INTEGER;
BEGIN
    -- Verify the target line exists
    SELECT COUNT(*) INTO v_count
    FROM   LIGNECOMMANDES1
    WHERE  IDLIGNECOMMANDE = p_idlignecommande;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20003,
            'updateligne [S1]: IDLIGNECOMMANDE=' || p_idlignecommande
            || ' does not exist in LIGNECOMMANDES1.');
    END IF;

    -- Verify the new product belongs to this fragment
    SELECT COUNT(*) INTO v_count
    FROM   PRODUITS1
    WHERE  IDPRODUIT = p_idproduit;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20002,
            'updateligne [S1]: IDPRODUIT=' || p_idproduit
            || ' does not exist in PRODUITS1.');
    END IF;

    UPDATE LIGNECOMMANDES1
    SET    IDPRODUIT = p_idproduit,
           QUANTITE  = p_quantite,
           REMISE    = p_remise
    WHERE  IDLIGNECOMMANDE = p_idlignecommande;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END updateligne;
/

-- =============================================================
-- Grants for g_user
-- g_user is the account used by the global DB database link.
-- It needs:
--   - CREATE SESSION to open a connection
--   - EXECUTE on each procedure so the sync triggers can call them
--   - SELECT on the fragment tables for the distributed query (Q6)
-- =============================================================
GRANT CREATE SESSION TO g_user;

GRANT EXECUTE ON pdb_admin.insertligne TO g_user;
GRANT EXECUTE ON pdb_admin.deleteligne TO g_user;
GRANT EXECUTE ON pdb_admin.updateligne TO g_user;

GRANT SELECT ON pdb_admin.LIGNECOMMANDES1 TO g_user;
GRANT SELECT ON pdb_admin.PRODUITS1       TO g_user;
GRANT SELECT ON pdb_admin.COMMANDES1      TO g_user;
GRANT SELECT ON pdb_admin.CLIENTS1        TO g_user;
