ALTER SESSION SET CONTAINER = G_PDB;
ALTER SESSION SET CURRENT_SCHEMA = pdb_admin;

-- CREATE ROLE site_role;

-- GRANT SELECT ON pdb_admin.CLIENTS TO site_role;
-- GRANT SELECT ON pdb_admin.FOURNISSEURS TO site_role;
-- GRANT SELECT ON pdb_admin.EMPLOYES TO site_role;
-- GRANT SELECT ON pdb_admin.CATEGORIES TO site_role;
-- GRANT SELECT ON pdb_admin.COMMANDES TO site_role;
-- GRANT SELECT ON pdb_admin.PRODUITS TO site_role;
-- GRANT SELECT ON pdb_admin.LigneCommandes TO site_role;
-- GRANT CREATE SESSION pdb_admin.TO site_role;

-- GRANT site_role TO s1_user;
-- GRANT site_role TO s2_user;

-- TODO: figure out how to do this, using roles
GRANT SELECT ON pdb_admin.CLIENTS        TO s1_user;
GRANT SELECT ON pdb_admin.FOURNISSEURS   TO s1_user;
GRANT SELECT ON pdb_admin.EMPLOYES       TO s1_user;
GRANT SELECT ON pdb_admin.CATEGORIES     TO s1_user;
GRANT SELECT ON pdb_admin.COMMANDES      TO s1_user;
GRANT SELECT ON pdb_admin.PRODUITS       TO s1_user;
GRANT SELECT ON pdb_admin.LIGNECOMMANDES TO s1_user;
GRANT CREATE SESSION TO s1_user;
GRANT EXECUTE ON pdb_admin.insert_ligne_commande TO s1_user;

GRANT SELECT ON pdb_admin.CLIENTS        TO s2_user;
GRANT SELECT ON pdb_admin.FOURNISSEURS   TO s2_user;
GRANT SELECT ON pdb_admin.EMPLOYES       TO s2_user;
GRANT SELECT ON pdb_admin.CATEGORIES     TO s2_user;
GRANT SELECT ON pdb_admin.COMMANDES      TO s2_user;
GRANT SELECT ON pdb_admin.PRODUITS       TO s2_user;
GRANT SELECT ON pdb_admin.LIGNECOMMANDES TO s2_user;
GRANT CREATE SESSION TO s2_user;

GRANT SELECT ON pdb_admin.CLIENTS        TO b_user;
GRANT SELECT ON pdb_admin.FOURNISSEURS   TO b_user;
GRANT SELECT ON pdb_admin.EMPLOYES       TO b_user;
GRANT SELECT ON pdb_admin.CATEGORIES     TO b_user;
GRANT SELECT ON pdb_admin.COMMANDES      TO b_user;
GRANT SELECT ON pdb_admin.PRODUITS       TO b_user;
GRANT SELECT ON pdb_admin.LIGNECOMMANDES TO b_user;
GRANT CREATE SESSION TO b_user;