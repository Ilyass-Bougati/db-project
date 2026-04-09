-- Connexion au conteneur PDB
ALTER SESSION SET CONTAINER = XEPDB1;

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

-- Création de l'utilisateur principal
CREATE USER mon_user IDENTIFIED BY mon_mdp
DEFAULT TABLESPACE USERS
QUOTA UNLIMITED ON USERS;

-- Accorder les privilèges de base
GRANT CONNECT, RESOURCE, CREATE SESSION, CREATE VIEW, CREATE TABLE, CREATE PROCEDURE, CREATE SEQUENCE, CREATE TRIGGER TO mon_user;

-- Accorder les droits sur le tablespace
GRANT UNLIMITED TABLESPACE TO mon_user;

-- Basculer sur le schéma de l'utilisateur
ALTER SESSION SET CURRENT_SCHEMA = mon_user;

-- Message de confirmation
SET SERVEROUTPUT ON;
BEGIN
    DBMS_OUTPUT.PUT_LINE('✅ Schema cree avec succes pour mon_user dans MARRAKECH');
END;
/