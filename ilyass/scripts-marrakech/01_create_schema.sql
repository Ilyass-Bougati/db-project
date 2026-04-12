-- Connect to the root container (CDB$ROOT)
ALTER SESSION SET CONTAINER = CDB$ROOT;

CREATE PLUGGABLE DATABASE MARRAKECH_PDB
  ADMIN USER pdb_admin IDENTIFIED BY Admin123
  ROLES = (DBA)
  DEFAULT TABLESPACE USERS
    DATAFILE '/opt/oracle/oradata/XE/MARRAKECH_PDB/users01.dbf'
    SIZE 250M AUTOEXTEND ON
  FILE_NAME_CONVERT = (
    '/opt/oracle/oradata/XE/pdbseed/',
    '/opt/oracle/oradata/XE/MARRAKECH_PDB/'
  );

-- Open the new PDB
ALTER PLUGGABLE DATABASE MARRAKECH_PDB OPEN;

-- Make it auto-open on DB restart
ALTER PLUGGABLE DATABASE MARRAKECH_PDB SAVE STATE;

-- Connexion au conteneur PDB
ALTER SESSION SET CONTAINER = MARRAKECH_PDB;

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

-- Création de l'utilisateur de casablanca
CREATE USER casablanca_user IDENTIFIED BY mon_mdp
DEFAULT TABLESPACE USERS
QUOTA UNLIMITED ON USERS;

-- Création de l'utilisateur de marrakech
CREATE USER rabat_user IDENTIFIED BY mon_mdp
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

-- Accorder les droits sur le tablespace
GRANT UNLIMITED TABLESPACE TO mon_user;

-- Basculer sur le schéma de l'utilisateur
ALTER SESSION SET CURRENT_SCHEMA = mon_user;

-- Message de confirmation
SET SERVEROUTPUT ON;
BEGIN
    DBMS_OUTPUT.PUT_LINE('✅ Schema cree avec succes pour mon_user dans RABAT');
END;
/