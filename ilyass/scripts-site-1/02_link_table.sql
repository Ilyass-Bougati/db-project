-- Connexion au conteneur PDB
CONNECT pdb_admin/Admin123@//localhost:1521/S1_PDB;

CREATE DATABASE LINK link_to_global
    CONNECT TO s1_user
    IDENTIFIED BY mon_mdp
    USING 'GLOBAL_DB_ALIAS';

-- -- -- Tables
CREATE OR REPLACE SYNONYM CLIENTS         FOR pdb_admin.CLIENTS@link_to_global;
CREATE OR REPLACE SYNONYM FOURNISSEURS    FOR pdb_admin.FOURNISSEURS@link_to_global;
CREATE OR REPLACE SYNONYM EMPLOYES        FOR pdb_admin.EMPLOYES@link_to_global;
CREATE OR REPLACE SYNONYM CATEGORIES      FOR pdb_admin.CATEGORIES@link_to_global;
CREATE OR REPLACE SYNONYM COMMANDES       FOR pdb_admin.COMMANDES@link_to_global;
CREATE OR REPLACE SYNONYM PRODUITS        FOR pdb_admin.PRODUITS@link_to_global;
CREATE OR REPLACE SYNONYM LIGNECOMMANDES  FOR pdb_admin.LIGNECOMMANDES@link_to_global;