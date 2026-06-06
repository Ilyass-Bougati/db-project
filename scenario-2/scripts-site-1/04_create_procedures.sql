-- =============================================================
-- Site 1 — Stored procedures for LIGNECOMMANDES1 (Q2)
-- Scenario 2: R1 = σ(QUANTITE >= 100)(LigneCommandes)
-- =============================================================

CONNECT pdb_admin/Admin123@//localhost:1521/S1_PDB;

-- =============================================================
-- PROCEDURE: insertligne
-- Inserts a new row into LIGNECOMMANDES1.
-- The global SYC_INSERT_LIGNE trigger guarantees that this
-- procedure is only called for rows with QUANTITE >= 100.
--
-- Arguments:
--   p_idlignecommande  PK of the new order line
--   p_idcommande       Must exist in COMMANDES1
--   p_idproduit        Must exist in PRODUITS1
--   p_quantite         Ordered quantity (>= 100 by contract)
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
    SELECT COUNT(*) INTO v_count
    FROM   COMMANDES1
    WHERE  IDCOMMANDE = p_idcommande;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001,
            'insertligne [S1]: IDCOMMANDE=' || p_idcommande
            || ' does not exist in COMMANDES1.');
    END IF;

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
-- Deletes a row from LIGNECOMMANDES1 by PK, then cascades
-- upward to remove orphaned COMMANDES1 / CLIENTS1 rows.
-- PRODUITS1 is not touched (product master data).
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
    SELECT IDCOMMANDE INTO v_idcommande
    FROM   LIGNECOMMANDES1
    WHERE  IDLIGNECOMMANDE = p_idlignecommande;

    SELECT IDCLIENT INTO v_idclient
    FROM   COMMANDES1
    WHERE  IDCOMMANDE = v_idcommande;

    DELETE FROM LIGNECOMMANDES1
    WHERE  IDLIGNECOMMANDE = p_idlignecommande;

    SELECT COUNT(*) INTO v_count
    FROM   LIGNECOMMANDES1
    WHERE  IDCOMMANDE = v_idcommande;

    IF v_count = 0 THEN
        DELETE FROM COMMANDES1 WHERE IDCOMMANDE = v_idcommande;

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
-- in LIGNECOMMANDES1.
--
-- The global SYC_UPDATE_LIGNE trigger only calls this procedure
-- when the row stays in Site 1 (old QUANTITE >= 100 AND new
-- QUANTITE >= 100).  Cross-boundary updates are handled by the
-- trigger via deleteligne + insertligne.
--
-- Arguments:
--   p_idlignecommande  PK of the line to update
--   p_idproduit        New product (must exist in PRODUITS1)
--   p_quantite         New quantity (>= 100 by caller contract)
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
    SELECT COUNT(*) INTO v_count
    FROM   LIGNECOMMANDES1
    WHERE  IDLIGNECOMMANDE = p_idlignecommande;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20003,
            'updateligne [S1]: IDLIGNECOMMANDE=' || p_idlignecommande
            || ' does not exist in LIGNECOMMANDES1.');
    END IF;

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
-- Grants for g_user (used by the global DB's database link)
-- =============================================================
GRANT CREATE SESSION TO g_user;

GRANT EXECUTE ON pdb_admin.insertligne TO g_user;
GRANT EXECUTE ON pdb_admin.deleteligne TO g_user;
GRANT EXECUTE ON pdb_admin.updateligne TO g_user;

GRANT SELECT ON pdb_admin.LIGNECOMMANDES1 TO g_user;
GRANT SELECT ON pdb_admin.PRODUITS1       TO g_user;
GRANT SELECT ON pdb_admin.COMMANDES1      TO g_user;
GRANT SELECT ON pdb_admin.CLIENTS1        TO g_user;
