CREATE DATABASE LINK link_to_rabat
    CONNECT TO casablanca_user
        IDENTIFIED BY mon_mdp
    USING '//db-rabat:1521/RABAT_PDB';

SELECT * FROM dual@link_to_rabat;

CREATE SYNONYM clients_rabat FOR PDB_ADMIN.CLIENTS@link_to_rabat;

SELECT * FROM clients_rabat;

DROP DATABASE LINK link_to_rabat;
DROP SYNONYM clients_rabat;