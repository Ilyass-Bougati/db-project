ALTER SESSION SET CONTAINER = G_PDB;
ALTER SESSION SET CURRENT_SCHEMA = pdb_admin;

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
