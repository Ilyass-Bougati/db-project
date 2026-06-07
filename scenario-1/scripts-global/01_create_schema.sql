-- Connect to the root container (CDB$ROOT)
ALTER SESSION SET CONTAINER = CDB$ROOT;

CREATE PLUGGABLE DATABASE G_PDB
  ADMIN USER pdb_admin IDENTIFIED BY Admin123
  ROLES = (DBA)
  DEFAULT TABLESPACE USERS
    DATAFILE '/opt/oracle/oradata/FREE/G_PDB/users01.dbf'
    SIZE 250M AUTOEXTEND ON
  FILE_NAME_CONVERT = (
    '/opt/oracle/oradata/FREE/pdbseed/',
    '/opt/oracle/oradata/FREE/G_PDB/'
  );

-- Open the new PDB
ALTER PLUGGABLE DATABASE G_PDB OPEN;

ALTER SYSTEM REGISTER;

-- Make it auto-open on DB restart
ALTER PLUGGABLE DATABASE G_PDB SAVE STATE;

-- Connexion au conteneur PDB
ALTER SESSION SET CONTAINER = G_PDB;

ALTER USER pdb_admin QUOTA UNLIMITED ON USERS;

-- Suppression de l'utilisateur s'il existe (pour faciliter les redémarrages)
BEGIN
   EXECUTE IMMEDIATE 'DROP USER mon_user CASCADE';
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE != -1918 THEN
         RAISE;
      END IF;
END;
/

-- TODO: Change these quotas to something reasonable
-- Création de l'utilisateur de site 2
CREATE USER s2_user IDENTIFIED BY mon_mdp
DEFAULT TABLESPACE USERS
QUOTA UNLIMITED ON USERS;

-- Création de l'utilisateur de site 1
CREATE USER s1_user IDENTIFIED BY mon_mdp
DEFAULT TABLESPACE USERS
QUOTA UNLIMITED ON USERS;

-- Création de l'utilisateur pour le backup DB (utilisé par le DB link depuis le backup)
CREATE USER b_user IDENTIFIED BY mon_mdp
DEFAULT TABLESPACE USERS
QUOTA UNLIMITED ON USERS;

-- Accorder les privilèges de base
-- TODO: fine tune these privileges
GRANT CREATE SESSION,
      CONNECT,
      RESOURCE,
      CREATE VIEW,
      CREATE TABLE,
      CREATE PROCEDURE,
      CREATE SEQUENCE,
      CREATE TRIGGER,
      CREATE SYNONYM,
      CREATE PUBLIC SYNONYM,
      CREATE DATABASE LINK,
      CREATE PUBLIC DATABASE LINK
TO pdb_admin;

-- Message de confirmation
SET SERVEROUTPUT ON;
BEGIN
    DBMS_OUTPUT.PUT_LINE('✅ Schema cree avec succes pour mon_user dans GLOBAL');
END;
/