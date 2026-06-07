# Documentation

## `rapport.tex` — Rapport technique (français)

Rapport LaTeX décrivant le système de bases de données réparties : architecture,
fragmentation horizontale, procédures stockées, synchronisation par
déclencheurs, optimisation des requêtes, sauvegarde et tableau de bord, avec
extraits de code commentés ainsi qu'une analyse des avantages et inconvénients.

### Compilation

Deux passes (pour résoudre la table des matières et les références) :

```bash
cd docs
pdflatex rapport.tex
pdflatex rapport.tex
```

> Aucune chaîne LaTeX n'est installée sur cette machine : le `.tex` n'a donc pas
> pu être compilé ici. Installez TeX Live puis lancez les commandes ci-dessus.

### Dépendances (paquets LaTeX)

`inputenc`, `fontenc`, `lmodern`, `babel` (français), `microtype`, `amsmath`,
`amssymb`, `geometry`, `graphicx`, `booktabs`, `enumitem`, `xcolor`, `fancyhdr`,
`listings`, `tikz` (+ bibliothèque `arrows.meta`), `hyperref`.

Le plus simple est d'installer la distribution complète :

```bash
# Debian / Ubuntu
sudo apt install texlive-full

# … ou, installation minimale ciblée :
sudo apt install texlive-latex-recommended texlive-latex-extra \
                 texlive-lang-french texlive-pictures texlive-fonts-recommended
```
