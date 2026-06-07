# Captures d'écran du rapport

Déposez ici les images référencées par `rapport.tex` (macro `\screenshot{...}`).
Tant qu'un fichier est absent, le rapport compile avec un cadre indiquant le
chemin attendu ; dès que l'image est présente, elle est insérée automatiquement
au recompilage.

Fichiers attendus :

| Fichier            | Contenu                                                        |
|--------------------|----------------------------------------------------------------|
| `docker-ps.png`    | Sortie de `docker compose ps` (les 4 nœuds à l'état `healthy`)  |
| `dashboard.png`    | Le tableau de bord Next.js                                      |
| `test-insert.png`  | Test d'insertion + propagation vers le site                    |
| `test-delete.png`  | Test de suppression + nettoyage en cascade                     |
| `test-update.png`  | Test de mise à jour (migration entre fragments)                |

Formats supportés par pdfLaTeX : PNG, JPG, PDF.
