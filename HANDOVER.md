# Reprise du développement — canObsR configuration builder 3.1.0

Ce document permet à une nouvelle personne de reprendre le projet sans dépendre de l’historique des conversations ayant conduit à la version 3.1.0.

## 1. Point de départ

- Version fonctionnelle : `3.1.0` (voir `VERSION`).
- Interface : application Shiny dans `scripts/config_builder_app/app.R`.
- API R : fonctions chargées par `scripts/load_config_functions.R`.
- Documentation utilisateur : `docs/configuration_files_guide.html`.
- Tests : `scripts/tests/testthat/test-schema-v3.1.0.R`.
- État des exigences : `IMPLEMENTATION_CHECKLIST.md`.
- État de la vérification : `QA_REPORT.md`.

L’application Shiny et les scripts directs doivent toujours appeler les mêmes fonctions métier. Une règle ne doit pas être réimplémentée uniquement dans l’interface.

## 2. Les quatre opérations publiques

| Opération | Fonction principale | Script d’exemple | Rôle |
| --- | --- | --- | --- |
| 1 — Generate | `operation1_generate_config()` | `operation1_generate_config.R` | Initialise les sous-dossiers puis écrit progressivement les fichiers validés. |
| 2 — Modify | `operation2_modify_config()` | `operation2_modify_config.R` | Compare l’état publié et le candidat, présente les impacts et republie. |
| 3 — Check | `operation3_check_parameters_and_data()` | `operation3_check_parameters_and_data.R` | Contrôle la configuration, le crownfile et les produits en résolvant les alias de serveurs. |
| 4 — Visualise | `operation4_visualize_parameters_and_data()` | `operation4_visualize_parameters_and_data.R` | Produit les vues d’inventaire et de couverture sans modifier les données scientifiques. |

Les anciens alias numérotés conservés à la fin de `workflow_checks.R` servent uniquement à la compatibilité. Tout nouveau code et toute documentation doivent employer les noms des quatre opérations ci-dessus.

## 3. Architecture du code

| Fichier | Responsabilité |
| --- | --- |
| `R/constants.R` | Schémas canoniques, catalogues, modèles de tables et ordre de l’assistant. |
| `R/io.R` | Lecture/écriture CSV, Excel et texte ; création des dossiers ; tables générées. |
| `R/validation.R` | Validation d’une table et validation inter-fichiers de la configuration. |
| `R/config_access.R` | Résolution sécurisée des chemins et accès aux fichiers éditables. |
| `R/change_management.R` | Captures avant/après, différences, impacts, archives et rapports de modification. |
| `R/observatory_yaml.R` | Construction du YAML et du rapport HTML de l’observatoire. |
| `R/product_discovery.R` | Compilation des patterns UAV, inventaire et rapport `products_check.txt`. |
| `R/workflow_api.R` | API publique pour contrôler, prévisualiser et écrire les fichiers. |
| `R/workflow_checks.R` | Contrôles connectés, crownfile, produits et orchestration des quatre opérations. |
| `R/ui_helpers.R` | Composants visuels et diagnostics de l’application Shiny. |
| `app.R` | État réactif, navigation et branchement des composants sur l’API commune. |

`scripts/load_config_observer.R` définit l’ordre de chargement des modules. Lorsqu’un nouveau module est ajouté, vérifier ses dépendances avant de modifier cet ordre.

## 4. Invariants à préserver

### Configuration

- Les CSV utilisent `;` et sont écrits en UTF-8.
- `param/crownfile_param.csv` commence par `path`, puis `server`.
- `path` désigne le chemin du crownfile à partir de la racine locale de l’alias `server`.
- `vectors.csv` est passif : aucune fonction métier ne doit lire son contenu.
- Le catalogue enregistré dans `product.csv` reste complet ; l’éditeur Shiny masque seulement les produits des surveys désactivés et les sauvegarde avec `status = FALSE`.
- Les fichiers conditionnels doivent apparaître immédiatement dans l’assistant après la sauvegarde de la valeur qui les active.

### Crownfiles

- Le format est toujours `.gpkg`.
- Le mode `light` contient exactement une couche spatiale appelée `crowns`.
- Le mode `dynamic` respecte les couches et variables déclarées dans `crownfile_vars.csv`.
- Après chaque `st_read()`, utiliser `normalize_sf_geometry_column()` afin que la colonne géométrique active soit appelée `geometry`, même si le GeoPackage stocke `geom`.
- Le contrôle des dates RGB dynamiques reste optionnel via `check_rgb_dates`.

### Produits UAV

- La découverte est non récursive : seuls les objets enfants immédiats sont examinés.
- Chaque ligne utilise soit `directory_pattern`, soit `filename_pattern`, jamais les deux.
- RGB, MS et DLS exigent exactement un placeholder de date pris en charge.
- Les patterns sont validés par `validate_uav_file_patterns()` et compilés par `template_to_regex()` ; toute évolution doit modifier et tester ces deux côtés ensemble.
- `products_check.txt` est écrit lors des contrôles connectés. `all_products.csv` n’est écrit que sur demande explicite après un contrôle sans erreur bloquante.

### Publication

- `generate_config_outputs()` constitue le point de publication commun à Shiny et R.
- La publication archive les versions précédentes du YAML, du rapport de site et des rapports de modification.
- Les collisions d’une même date utilisent les suffixes `_2`, `_3`, etc.
- Le rapport de modification exclut le rapport HTML dérivé, conserve les CSV et YAML bruts copiables, et place les blocs YAML à la fin.
- Le rapport `{site.name}_observatory_infos.html` omet toute table optionnelle absente.

## 5. Flux de validation

1. La table courante est validée avant toute écriture.
2. Les dépendances déjà disponibles dans `config/` alimentent la validation inter-fichiers.
3. Les erreurs sont bloquantes ; les warnings sont conservés dans le résultat.
4. L’opération 3 peut retourner `PASS WITH WARNINGS`.
5. Les contrôles connectés résolvent les alias trouvés dans `crownfile_param.csv` et `UAV_folder.csv` avec `server_roots`, par exemple `c(E = "E:/")`.
6. Les données scientifiques sont lues pour vérification mais ne sont jamais modifiées.

Ne pas réintroduire un verrou imposant une republication simplement parce que le YAML ou un rapport dérivé diffère : ces différences doivent être diagnostiquées sans rendre impossible le contrôle d’une configuration valide.

## 6. Développer une modification

1. Écrire ou mettre à jour le test de régression dans `test-schema-v3.1.0.R`.
2. Modifier la fonction métier commune dans `R/`, pas seulement `app.R`.
3. Mettre à jour le script d’exemple concerné.
4. Mettre à jour le générateur `scripts/build_configuration_guide.py`, puis reconstruire le HTML ; ne pas éditer uniquement le HTML généré.
5. Exécuter les tests et contrôler visuellement l’application Shiny.
6. Mettre à jour `QA_REPORT.md`, `IMPLEMENTATION_CHECKLIST.md` et les notes de version si le contrat change.

## 7. Commandes de contrôle

Depuis la racine du dépôt :

```r
source("scripts/install_dependencies.R")
source("scripts/tests/testthat.R")
source("scripts/run_config_builder.R")
```

Pour reconstruire le guide :

```bash
python3 scripts/build_configuration_guide.py
```

Vérifier ensuite les deux langues, le sommaire latéral, les liens internes et les exemples CSV dans `docs/configuration_files_guide.html`.

## 8. Limites connues au moment de la passation

- La dernière construction a fait l’objet d’audits statiques, mais la suite `testthat` n’a pas pu être exécutée dans l’environnement de construction faute de runtime R.
- Une exécution sur Windows est prioritaire, car les exemples de serveurs et les chemins utilisateurs emploient fréquemment des lecteurs tels que `E:/`.
- Les vérifications nécessitant de véritables GeoPackages et arborescences UAV doivent être rejouées avec un petit jeu de données de test maîtrisé.
- Le code est distribué sous GNU GPL v3 ; toute évolution des conditions de distribution doit faire l’objet d’une décision explicite du responsable du dépôt.

## 9. Vérification minimale avant la prochaine publication

- [ ] Tous les tests `testthat` passent sur une version documentée de R.
- [ ] Les quatre scripts d’exemple s’exécutent dans leur ordre.
- [ ] Le parcours Shiny complet fonctionne avec un crownfile `light`.
- [ ] Le parcours Shiny complet fonctionne avec un crownfile `dynamic`.
- [ ] Les alias de serveurs sont détectés et résolus dans l’opération 3.
- [ ] `PASS`, `PASS WITH WARNINGS` et `FAIL` sont tous testés.
- [ ] `all_products.csv` et `products_check.txt` sont régénérés sur un inventaire réel.
- [ ] La modification et la republication créent les bonnes archives et le bon rapport daté.
- [ ] Le guide anglais/français reflète exactement les règles du code.

## 10. Ordre conseillé pour la reprise

1. Installer R et les dépendances.
2. Exécuter la suite existante sans modifier le code et conserver le résultat comme référence.
3. Faire un parcours manuel Shiny sur une copie jetable d’un site de test.
4. Ouvrir une issue GitHub par changement fonctionnel.
5. Développer sur une branche dédiée et faire relire la pull request avant fusion dans `main`.
