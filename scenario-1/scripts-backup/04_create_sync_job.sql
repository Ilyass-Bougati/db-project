CONNECT pdb_admin/Admin123@//localhost:1521/B_PDB;

-- =============================================================
-- sync_from_global
-- Full reload: truncates every backup table (leaf-to-root to
-- respect implicit ordering) then re-inserts all rows from the
-- global DB via link_to_global (root-to-leaf to avoid any
-- temporary constraint violations even though FKs are absent).
-- =============================================================
CREATE OR REPLACE PROCEDURE pdb_admin.sync_from_global AS
BEGIN
    -- Truncate in reverse dependency order (children first)
    EXECUTE IMMEDIATE 'TRUNCATE TABLE pdb_admin.LIGNECOMMANDES';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE pdb_admin.COMMANDES';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE pdb_admin.PRODUITS';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE pdb_admin.CLIENTS';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE pdb_admin.EMPLOYES';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE pdb_admin.FOURNISSEURS';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE pdb_admin.CATEGORIES';

    -- Reload in dependency order (parents first)
    INSERT INTO pdb_admin.CATEGORIES     SELECT * FROM pdb_admin.CATEGORIES@link_to_global;
    INSERT INTO pdb_admin.FOURNISSEURS   SELECT * FROM pdb_admin.FOURNISSEURS@link_to_global;
    INSERT INTO pdb_admin.EMPLOYES       SELECT * FROM pdb_admin.EMPLOYES@link_to_global;
    INSERT INTO pdb_admin.CLIENTS        SELECT * FROM pdb_admin.CLIENTS@link_to_global;
    INSERT INTO pdb_admin.COMMANDES      SELECT * FROM pdb_admin.COMMANDES@link_to_global;
    INSERT INTO pdb_admin.PRODUITS       SELECT * FROM pdb_admin.PRODUITS@link_to_global;
    INSERT INTO pdb_admin.LIGNECOMMANDES SELECT * FROM pdb_admin.LIGNECOMMANDES@link_to_global;

    COMMIT;
END sync_from_global;
/

-- =============================================================
-- BACKUP_SYNC_JOB — runs sync_from_global every hour
-- =============================================================
BEGIN
    DBMS_SCHEDULER.DROP_JOB('BACKUP_SYNC_JOB', force => TRUE);
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'BACKUP_SYNC_JOB',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'pdb_admin.sync_from_global',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=HOURLY;INTERVAL=1',
        enabled         => TRUE,
        comments        => 'Full reload of all backup tables from the global DB'
    );
END;
/
