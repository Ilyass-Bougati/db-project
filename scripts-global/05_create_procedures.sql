-- Connexion au conteneur PDB
ALTER SESSION SET CONTAINER = G_PDB;
ALTER SESSION SET CURRENT_SCHEMA = pdb_admin;

CREATE OR REPLACE PROCEDURE insert_ligne_commande (
    p_idlignecommande IN LigneCommandes.IDLIGNECOMMANDE%TYPE,
    p_idcommande      IN LigneCommandes.IDCOMMANDE%TYPE,
    p_idproduit       IN LigneCommandes.IDPRODUIT%TYPE,
    p_quantite        IN LigneCommandes.QUANTITE%TYPE,
    p_remise          IN LigneCommandes.REMISE%TYPE
)
IS
BEGIN
    -- Execute the insert statement
    INSERT INTO LigneCommandes (
        IDLIGNECOMMANDE, 
        IDCOMMANDE, 
        IDPRODUIT, 
        QUANTITE, 
        REMISE
    ) VALUES (
        p_idlignecommande, 
        p_idcommande, 
        p_idproduit, 
        p_quantite, 
        p_remise
    );

    -- Commit the transaction if successful
    COMMIT;

EXCEPTION
    -- Catch any errors (e.g., foreign key violations, duplicate primary keys)
    WHEN OTHERS THEN
        -- Rollback the transaction to keep data consistent
        ROLLBACK;
        -- Re-raise the error so the calling application knows it failed
        RAISE;
END insert_ligne_commande;
/