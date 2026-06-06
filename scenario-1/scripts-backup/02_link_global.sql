CONNECT pdb_admin/Admin123@//localhost:1521/B_PDB;

-- DB link to the global DB; connects as b_user (read-only account on G_PDB)
BEGIN EXECUTE IMMEDIATE 'DROP DATABASE LINK link_to_global'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE DATABASE LINK link_to_global
    CONNECT TO b_user
    IDENTIFIED BY mon_mdp
    USING 'GLOBAL_DB_ALIAS';
