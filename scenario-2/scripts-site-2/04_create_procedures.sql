-- =============================================================
-- Site 2 — Stored procedures for LIGNECOMMANDES2 (Q3)
-- Scenario 2: R2 = σ(QUANTITE < 100)(LigneCommandes)
-- Mirror of scripts-site-1/04_create_procedures.sql, operating
-- on the *2 fragment tables with the same contract.
-- =============================================================

CONNECT pdb_admin/Admin123@//localhost:1521/S2_PDB;

-- =============================================================
-- PROCEDURE: insertligne
-- Inserts a new row into LIGNECOMMANDES2.
-- The global SYC_INSERT_LIGNE trigger guarantees that this
-- procedure is only called for rows with QUANTITE < 100.
-- =============================================================
CREATE OR REPLACE PROCEDURE insertligne (
    p_idlignecommande IN LIGNECOMMANDES2.IDLIGNECOMMANDE%TYPE,
    p_idcommande      IN LIGNECOMMANDES2.IDCOMMANDE%TYPE,
    p_idproduit       IN LIGNECOMMANDES2.IDPRODUIT%TYPE,
    p_quantite        IN LIGNECOMMANDES2.QUANTITE%TYPE,
    p_remise          IN LIGNECOMMANDES2.REMISE%TYPE
)
IS
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM   COMMANDES2
    WHERE  IDCOMMANDE = p_idcommande;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001,
            'insertligne [S2]: IDCOMMANDE=' || p_idcommande
            || ' does not exist in COMMANDES2.');
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM   PRODUITS2
    WHERE  IDPRODUIT = p_idproduit;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20002,
            'insertligne [S2]: IDPRODUIT=' || p_idproduit
            || ' does not exist in PRODUITS2.');
    END IF;

    INSERT INTO LIGNECOMMANDES2 (IDLIGNECOMMANDE, IDCOMMANDE, IDPRODUIT, QUANTITE, REMISE)
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
-- Deletes a row from LIGNECOMMANDES2 by PK, then cascades
-- upward to remove orphaned COMMANDES2 / CLIENTS2 rows.
-- =============================================================
CREATE OR REPLACE PROCEDURE deleteligne (
    p_idlignecommande IN LIGNECOMMANDES2.IDLIGNECOMMANDE%TYPE
)
IS
    v_idcommande LIGNECOMMANDES2.IDCOMMANDE%TYPE;
    v_idclient   COMMANDES2.IDCLIENT%TYPE;
    v_count      INTEGER;
BEGIN
    SELECT IDCOMMANDE INTO v_idcommande
    FROM   LIGNECOMMANDES2
    WHERE  IDLIGNECOMMANDE = p_idlignecommande;

    SELECT IDCLIENT INTO v_idclient
    FROM   COMMANDES2
    WHERE  IDCOMMANDE = v_idcommande;

    DELETE FROM LIGNECOMMANDES2
    WHERE  IDLIGNECOMMANDE = p_idlignecommande;

    SELECT COUNT(*) INTO v_count
    FROM   LIGNECOMMANDES2
    WHERE  IDCOMMANDE = v_idcommande;

    IF v_count = 0 THEN
        DELETE FROM COMMANDES2 WHERE IDCOMMANDE = v_idcommande;

        SELECT COUNT(*) INTO v_count
        FROM   COMMANDES2
        WHERE  IDCLIENT = v_idclient;

        IF v_count = 0 THEN
            DELETE FROM CLIENTS2 WHERE IDCLIENT = v_idclient;
        END IF;
    END IF;

    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20003,
            'deleteligne [S2]: IDLIGNECOMMANDE=' || p_idlignecommande
            || ' does not exist in LIGNECOMMANDES2.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END deleteligne;
/

-- =============================================================
-- PROCEDURE: updateligne
-- Updates IDPRODUIT, QUANTITE, and REMISE for an existing row
-- in LIGNECOMMANDES2.
--
-- The global SYC_UPDATE_LIGNE trigger only calls this procedure
-- when the row stays in Site 2 (old QUANTITE < 100 AND new
-- QUANTITE < 100).
-- =============================================================
CREATE OR REPLACE PROCEDURE updateligne (
    p_idlignecommande IN LIGNECOMMANDES2.IDLIGNECOMMANDE%TYPE,
    p_idproduit       IN LIGNECOMMANDES2.IDPRODUIT%TYPE,
    p_quantite        IN LIGNECOMMANDES2.QUANTITE%TYPE,
    p_remise          IN LIGNECOMMANDES2.REMISE%TYPE
)
IS
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM   LIGNECOMMANDES2
    WHERE  IDLIGNECOMMANDE = p_idlignecommande;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20003,
            'updateligne [S2]: IDLIGNECOMMANDE=' || p_idlignecommande
            || ' does not exist in LIGNECOMMANDES2.');
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM   PRODUITS2
    WHERE  IDPRODUIT = p_idproduit;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20002,
            'updateligne [S2]: IDPRODUIT=' || p_idproduit
            || ' does not exist in PRODUITS2.');
    END IF;

    UPDATE LIGNECOMMANDES2
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

GRANT SELECT ON pdb_admin.LIGNECOMMANDES2 TO g_user;
GRANT SELECT ON pdb_admin.PRODUITS2       TO g_user;
GRANT SELECT ON pdb_admin.COMMANDES2      TO g_user;
GRANT SELECT ON pdb_admin.CLIENTS2        TO g_user;
