from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "docs" / "configuration_files_guide.html"


def table(headers, rows):
    head = "".join(f"<th>{cell}</th>" for cell in headers)
    body = "".join(
        "<tr>" + "".join(f"<td>{cell}</td>" for cell in row) + "</tr>"
        for row in rows
    )
    return f"<div class='table-wrap'><table><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table></div>"


def csv(text):
    return f"<pre><code>{escape(text.strip())}</code></pre>"


def section(anchor, title, body):
    return f"<section id='{anchor}'><h2>{title}</h2>{body}</section>"


PRODUCTS = """survey;product;status
RGB;RGB_raw;TRUE
RGB;RGB_orthomosaic;TRUE
RGB;RGB_DEM;FALSE
RGB;RGB_vignette;FALSE
RGB;RGB_indices;FALSE
RGB;RGB_phenophase;FALSE"""

DAWKINS_PARAM = """param;value
daw5_H_ratio;1.5
daw5_ratio_mean;1.3
daw3_H_ratio;1.1
daw3_ratio_mean;1.0
daw5b_ratio_min_strict;1.3
daw5b_ratio_min_souple;1.1
daw5b_slope_norm;-0.015
daw4c_ratio_above1;0.88
daw4c_ratio_cv;0.2
daw4a_ratio_above1;0.62
daw3c_openness;0.08
daw3c_ratio_above1;0.38
daw3a_ratio_above1;0.25
daw3a_openness;-0.05"""

DAWKINS = """Dawkins
3a - Some overhead light
3b - Some overhead light
3c - Lower canopy
4a - Full overhead light
4b - Full overhead light
4c - Canopy
5a - Emergent
5b - Emergent"""

CROWNFILE_VARS = """layer;var_name;type;reference_tables;reference_layer;exemple
geometry;site;chr;;;mba
geometry;geom_id;integer PK;;;23
geometry;id;integer FK;crowns.gpkg;infos;112
geometry;date;date;;;20221125
geometry;Tree_Status;chr FK;tree_status.csv;;Alive
geometry;version;integer;;;2
geometry;Geom_Modif;chr FK;geom_modif.csv;;Geometrical_Correction
geometry;geometry;MULTIPOLYGON;;;NA
infos;site;chr;;;mba
infos;id;integer PK;;;112
infos;tax_sp_level;chr;;;Lophira alata
infos;tax_gen;chr;;;Lophira
infos;tax_fam;chr;;;Ochnaceae
infos;Type_Obs;chr FK;type_obs.csv;;Field
infos;lianas;integer FK;lianas.csv;;0
infos;comments;chr;;;
infos;creator;chr FK;contributors.csv;;Alex
infos;dbh;dbl;;;25.6
infos;dbh_type;chr FK;dbh_types.csv;;measured
infos;crown_area;dbl;;;741
infos;plot_name;chr FK;plots_list.csv;;mbalmayo003
infos;taxa_id;integer FK;taxa_ref.csv;;1289
infos;dawkins_code;chr FK;dawkins.csv;;4c - Canopy"""

CROWNFILE_VARS_LIGHT = """layer;var_name;type;reference_tables;reference_layer;exemple
crowns;site;chr;;;mba
crowns;id;integer PK;;;112
crowns;date;date;;;20221125
crowns;geometry;MULTIPOLYGON;;;NA
crowns;tax_sp_level;chr;;;Lophira alata
crowns;tax_gen;chr;;;Lophira
crowns;tax_fam;chr;;;Ochnaceae
crowns;Type_Obs;chr FK;type_obs.csv;;Field
crowns;lianas;integer FK;lianas.csv;;0
crowns;comments;chr;;;
crowns;creator;chr FK;contributors.csv;;Alex
crowns;dbh;dbl;;;25.6
crowns;dbh_type;chr FK;dbh_types.csv;;measured
crowns;crown_area;dbl;;;741"""

ARCH_EN = """config/
├── param/
│   ├── site.csv                         [entered]
│   ├── survey.csv                       [entered]
│   ├── sensor.csv                       [entered]
│   ├── product.csv                      [entered]
│   ├── crownfile_param.csv              [entered]
│   ├── crownfile_vars.csv               [generated]
│   ├── tree_picture_zooms.csv           [entered, conditional]
│   └── dawkins_param.csv                [entered, conditional]
├── reference/
│   ├── contributors.csv                 [entered]
│   ├── plots_list.csv                   [entered, conditional]
│   ├── taxa_ref.csv                     [entered, conditional, unchecked]
│   ├── dawkins.csv                      [generated, conditional]
│   ├── dbh_types.csv                    [generated]
│   ├── geom_modif.csv                   [generated, conditional]
│   ├── lianas.csv                       [generated]
│   ├── tree_status.csv                  [generated, conditional]
│   └── type_obs.csv                     [generated]
├── path/
│   ├── UAV_folder.csv                   [entered]
│   ├── UAV_file_patterns.csv            [entered]
│   └── vectors.csv                      [entered, ignored]
├── archive/                              [previous publication files]
│   ├── observatory_before_yyyymmdd[_n].yaml
│   ├── site_check_before_yyyymmdd[_n].txt
│   └── modification_yyyymmdd[_n].txt
├── observatory.yaml                     [generated at the end, not connected with data]
├── modification_yyyymmdd[_n].txt        [generated at publication]
├── all_products.csv                     [generated later, connected with data]
├── products_check.txt                   [generated later, connected with data]
├── {site.name}_observatory_infos.html   [generated at the end, not connected with data]
└── site_check.txt                       [generated at the end, not connected with data]"""

ARCH_FR = """config/
├── param/
│   ├── site.csv                         [saisi]
│   ├── survey.csv                       [saisi]
│   ├── sensor.csv                       [saisi]
│   ├── product.csv                      [saisi]
│   ├── crownfile_param.csv              [saisi]
│   ├── crownfile_vars.csv               [généré]
│   ├── tree_picture_zooms.csv           [saisi, conditionnel]
│   └── dawkins_param.csv                [saisi, conditionnel]
├── reference/
│   ├── contributors.csv                 [saisi]
│   ├── plots_list.csv                   [saisi, conditionnel]
│   ├── taxa_ref.csv                     [saisi, conditionnel, non contrôlé]
│   ├── dawkins.csv                      [généré, conditionnel]
│   ├── dbh_types.csv                    [généré]
│   ├── geom_modif.csv                   [généré, conditionnel]
│   ├── lianas.csv                       [généré]
│   ├── tree_status.csv                  [généré, conditionnel]
│   └── type_obs.csv                     [généré]
├── path/
│   ├── UAV_folder.csv                   [saisi]
│   ├── UAV_file_patterns.csv            [saisi]
│   └── vectors.csv                      [saisi, ignoré]
├── archive/                              [fichiers des publications précédentes]
│   ├── observatory_before_yyyymmdd[_n].yaml
│   ├── site_check_before_yyyymmdd[_n].txt
│   └── modification_yyyymmdd[_n].txt
├── observatory.yaml                     [généré à la fin, non connecté aux données]
├── modification_yyyymmdd[_n].txt        [généré à la publication]
├── all_products.csv                     [généré plus tard, connecté aux données]
├── products_check.txt                   [généré plus tard, connecté aux données]
├── {site.name}_observatory_infos.html   [généré à la fin, non connecté aux données]
└── site_check.txt                       [généré à la fin, non connecté aux données]"""

WORKFLOW_EN = [
    ("1", "param/site.csv", "Always"),
    ("2", "param/survey.csv", "Always"),
    ("3", "param/sensor.csv", "Always"),
    ("4", "param/product.csv", "Always"),
    ("5", "param/crownfile_param.csv", "Always"),
    ("6", "param/tree_picture_zooms.csv", "tree_pictures = TRUE"),
    ("7", "reference/contributors.csv", "Always"),
    ("8", "reference/plots_list.csv", "plots_list = TRUE"),
    ("9", "param/dawkins_param.csv", "dawkins = TRUE"),
    ("10", "reference/taxa_ref.csv", "taxa_ref = TRUE"),
    ("11", "Generated files", "After user-entered reference files"),
    ("12", "path/UAV_folder.csv", "Always"),
    ("13", "path/UAV_file_patterns.csv", "Always"),
    ("14", "path/vectors.csv", "May be empty; ignored by the pipeline"),
    ("15", "observatory.yaml and site HTML report", "After the global configuration check"),
]

WORKFLOW_FR = [
    ("1", "param/site.csv", "Toujours"),
    ("2", "param/survey.csv", "Toujours"),
    ("3", "param/sensor.csv", "Toujours"),
    ("4", "param/product.csv", "Toujours"),
    ("5", "param/crownfile_param.csv", "Toujours"),
    ("6", "param/tree_picture_zooms.csv", "tree_pictures = TRUE"),
    ("7", "reference/contributors.csv", "Toujours"),
    ("8", "reference/plots_list.csv", "plots_list = TRUE"),
    ("9", "param/dawkins_param.csv", "dawkins = TRUE"),
    ("10", "reference/taxa_ref.csv", "taxa_ref = TRUE"),
    ("11", "Fichiers générés", "Après les références saisies par l’utilisateur"),
    ("12", "path/UAV_folder.csv", "Toujours"),
    ("13", "path/UAV_file_patterns.csv", "Toujours"),
    ("14", "path/vectors.csv", "Peut être vide ; ignoré par la pipeline"),
    ("15", "observatory.yaml et rapport HTML du site", "Après le contrôle global de configuration"),
]


def general(lang):
    if lang == "en":
        conventions = table(["Item", "Requirement"], [
            ["Version", "3.1.0"],
            ["Canonical surveys", "RGB, MS, DLS, tree_pictures in survey.csv and every other file."],
            ["Booleans", "TRUE or FALSE, uppercase and unquoted."],
            ["Date", "Every date uses yyyymmdd."],
            ["Plot reference", "plots_list and reference/plots_list.csv."],
            ["Taxonomic reference", "reference/taxa_ref.csv."],
            ["Equivalence", "Shiny and direct R calls produce the same diagnostics."],
        ]) + table(["Level", "Expected effect"], [
            ["Blocking error", "Prevents the current file from being saved or prevents final publication."],
            ["Warning", "Is reported but does not block saving or publication."],
        ])
        workflow_intro = """
        <p>Operation 1 begins by creating only <code>config/param</code>, <code>config/reference</code>, and
        <code>config/path</code>. It creates no CSV. At each step, the table is editable immediately. An
        imported CSV or Excel file replaces the draft shown on screen but remains editable. The file is
        written only after <strong>Validate and save</strong> succeeds; <strong>Next file</strong> then opens the
        following applicable step.</p>
        <p>Operation 2 loads an existing configuration. The published and candidate tables are shown side by side.
        Modified cells, deleted rows, and added rows have distinct colours. A panel below the tables lists the
        consequences for dependent configuration files and later data checks.</p>
        <p>Every save checks the current file and its consistency with already validated files. Step 15 runs
        the complete configuration-only check. After it passes, the previous YAML and site check are moved to
        <code>archive/</code>, a dated modification report records before/after file contents, and all derived
        configuration reports are rebuilt. Same-day publications use <code>_2</code>, <code>_3</code>, and so on.
        Operation 1 never tests a
        configured path, opens scientific data, or requires server access. In operation 3, Shiny reads the
        server aliases declared in crownfile_param.csv and UAV_folder.csv and displays one local-root field for
        each alias. Operation 3 resolves the crownfile from those mappings and applies the publication lock
        before scientific-data checks. Every opened GeoPackage layer has its active sf geometry column normalized
        to <code>geometry</code>, including layers stored with a column named <code>geom</code>. The product scan
        always writes <code>products_check.txt</code>. A successful result displays <strong>PASS</strong> or
        <strong>PASS WITH WARNINGS</strong> and enables <strong>Generate or update all_products.csv</strong> plus
        a detailed or grouped raw/processed comparison. The four
        operations — <strong>Generate the config folder</strong>, <strong>Modify the config folder</strong>,
        <strong>Check parameters and data</strong>, and <strong>Visualise parameters and data</strong> — are
        available in Shiny and through direct R calls.</p>"""
        return section("en-0", "0. General conventions", conventions + "<h3>0.1 Target config architecture</h3><p>Bracketed annotations are not part of file names.</p>" + csv(ARCH_EN) + "<h3>0.2 General creation and validation workflow</h3>" + table(["Order", "Step", "Condition"], WORKFLOW_EN) + workflow_intro)

    conventions = table(["Élément", "Exigence"], [
        ["Version", "3.1.0"],
        ["Surveys canoniques", "RGB, MS, DLS, tree_pictures dans survey.csv et dans tous les autres fichiers."],
        ["Booléens", "TRUE ou FALSE, en majuscules et sans guillemets."],
        ["Date", "Toutes les dates sont au format yyyymmdd."],
        ["Référence de placettes", "plots_list et reference/plots_list.csv."],
        ["Référence taxonomique", "reference/taxa_ref.csv."],
        ["Équivalence", "Les contrôles Shiny et les contrôles de l’API R produisent les mêmes diagnostics."],
    ]) + table(["Niveau", "Effet attendu"], [
        ["Erreur bloquante", "Empêche la sauvegarde du fichier courant ou la publication finale."],
        ["Warning", "Est signalé sans bloquer la sauvegarde ou la publication."],
    ])
    workflow_intro = """
    <p>L’opération 1 commence par créer uniquement <code>config/param</code>, <code>config/reference</code> et
    <code>config/path</code>. Aucun CSV n’est créé à ce stade. À chaque étape, le tableau est immédiatement
    modifiable. L’import d’un CSV ou d’un fichier Excel remplace le brouillon affiché, qui reste modifiable.
    Le fichier est écrit uniquement après la réussite de <strong>Validate and save</strong> ; le bouton
    <strong>Next file</strong> ouvre alors l’étape applicable suivante.</p>
    <p>L’opération 2 charge une configuration existante. Le tableau publié et le tableau candidat sont affichés
    côte à côte. Les cellules modifiées, les lignes supprimées et les lignes ajoutées ont des couleurs distinctes.
    Une fenêtre sous les tableaux décrit les conséquences pour les autres fichiers de configuration et les futurs
    contrôles de données.</p>
    <p>Chaque sauvegarde contrôle le fichier courant et sa cohérence avec les fichiers déjà validés. L’étape 15
    exécute le contrôle global limité à la configuration. Après sa réussite, le YAML et le contrôle de site
    précédents sont déplacés dans <code>archive/</code>, un rapport daté conserve les contenus avant/après, puis
    tous les rapports dérivés sont reconstruits. Plusieurs publications le même jour utilisent les suffixes
    <code>_2</code>, <code>_3</code>, etc. L’opération 1 ne
    teste aucun chemin configuré, n’ouvre aucune donnée scientifique et ne nécessite aucun serveur. Dans
    l’opération 3, Shiny lit les alias déclarés dans crownfile_param.csv et UAV_folder.csv et affiche un champ de
    racine locale pour chacun. L’opération 3 résout le crownfile depuis ces correspondances et applique le verrou
    de publication avant les contrôles de données scientifiques. La colonne géométrique sf de chaque couche
    GeoPackage ouverte est immédiatement renommée <code>geometry</code>, y compris lorsqu’elle est stockée sous
    le nom <code>geom</code>. Le scan des produits écrit toujours <code>products_check.txt</code>. Un contrôle
    réussi affiche <strong>PASS</strong> ou <strong>PASS WITH WARNINGS</strong> et active
    <strong>Generate or update all_products.csv</strong>, ainsi qu’une comparaison raw/processed détaillée ou
    regroupée. Les quatre opérations — <strong>Generate the config folder</strong>,
    <strong>Modify the config folder</strong>, <strong>Check parameters and data</strong> et
    <strong>Visualise parameters and data</strong> — sont disponibles dans Shiny et par appels R directs.</p>"""
    return section("fr-0", "0. Conventions générales", conventions + "<h3>0.1 Architecture cible du dossier config</h3><p>Les annotations entre crochets ne font pas partie des noms de fichiers.</p>" + csv(ARCH_FR) + "<h3>0.2 Workflow général de création et de validation</h3>" + table(["Ordre", "Étape", "Condition"], WORKFLOW_FR) + workflow_intro)


def steps(lang):
    fr = lang == "fr"
    p = "fr" if fr else "en"
    sections = []

    site_rows = [
        ["param", "Valeurs exactes et ordonnées : id_site, name, location, crs. Aucune ligne supplémentaire." if fr else "Exact ordered values: id_site, name, location, crs. No additional row."],
        ["id_site", "Obligatoire ; lettres ASCII, chiffres, underscore, tiret et point uniquement. Aucun espace." if fr else "Required; ASCII letters, digits, underscore, hyphen, and dot only. No spaces."],
        ["name", "Obligatoire ; espaces permis ; caractères accentués interdits." if fr else "Required; spaces allowed; accented characters forbidden."],
        ["location", "Obligatoire ; espaces permis ; caractères accentués interdits." if fr else "Required; spaces allowed; accented characters forbidden."],
        ["crs", "CRS obligatoire reconnu par sf, par exemple EPSG:32632." if fr else "Required CRS recognized by sf, for example EPSG:32632."],
        ["Placeholders", "Utiliser <code>{site.&lt;param&gt;}</code> ; voir l’étape 13." if fr else "Use <code>{site.&lt;param&gt;}</code>; see step 13."],
    ]
    sections.append(section(f"{p}-1", "1. param/site.csv", table(["Champ" if fr else "Field", "Exigence" if fr else "Requirement"], site_rows) + csv("""param;site_value
id_site;mba
name;Mbalmayo
location;Cameroon
crs;EPSG:32632""")))

    survey_rows = [
        ["survey", "Exactement RGB, MS, DLS et tree_pictures, une fois chacun. Les quatre lignes sont toujours présentes ; ordre libre." if fr else "Exactly RGB, MS, DLS, and tree_pictures, once each. All four rows are always present; any order."],
        ["status", "TRUE ou FALSE. Au moins un survey est TRUE. Un survey désactivé reste présent avec FALSE." if fr else "TRUE or FALSE. At least one survey is TRUE. A disabled survey remains present with FALSE."],
    ]
    sections.append(section(f"{p}-2", "2. param/survey.csv", table(["Champ" if fr else "Field", "Exigence" if fr else "Requirement"], survey_rows) + csv("""survey;status
RGB;TRUE
MS;FALSE
DLS;FALSE
tree_pictures;FALSE""")))

    sensor = """<ul>
    <li>Colonnes exactes : <code>sensor;survey;start_date;end_date;status</code>.</li>
    <li>Clé unique : <code>sensor/survey/start_date</code>.</li>
    <li>Dates au format yyyymmdd ; périodes inclusives. Aucun chevauchement au sein d’un même survey, y compris entre deux périodes du même sensor. Les trous et <code>end_date = start_date</code> sont autorisés.</li>
    <li><code>active</code> impose une end_date vide et représente une période ouverte jusqu’à aujourd’hui. <code>not active</code> impose une end_date supérieure ou égale à start_date.</li>
    <li>Un sensor peut couvrir plusieurs surveys. Une ligne pour un survey FALSE ou un survey actif sans aucun sensor est bloquante. Un survey actif possédant seulement des sensors historiques produit un warning.</li>
    </ul>""" if fr else """<ul>
    <li>Exact columns: <code>sensor;survey;start_date;end_date;status</code>.</li>
    <li>Unique key: <code>sensor/survey/start_date</code>.</li>
    <li>Dates use yyyymmdd; periods are inclusive. No overlap is allowed within a survey, including two periods of the same sensor. Gaps and <code>end_date = start_date</code> are allowed.</li>
    <li><code>active</code> requires an empty end_date and is open through today. <code>not active</code> requires an end_date on or after start_date.</li>
    <li>A sensor may cover several surveys. A row for a FALSE survey or an active survey without any sensor is blocking. An active survey with historical sensors only produces a warning.</li>
    </ul>"""
    sections.append(section(f"{p}-3", "3. param/sensor.csv", sensor + csv("""sensor;survey;start_date;end_date;status
Mavic2;RGB;20220730;;active""")))

    product_text = "Le catalogue canonique contient 17 couples survey/product. Dans l’éditeur Shiny de l’opération 1, seules les lignes des surveys ayant status TRUE sont affichées ; l’exemple ci-dessous correspond donc à RGB seul. Lors de la sauvegarde, les lignes masquées des surveys FALSE sont conservées automatiquement avec status FALSE afin que product.csv reste un fichier canonique complet. Pour chaque survey actif, tous ses produits sont présents : au moins un vaut TRUE, un produit FALSE produit un warning et un produit dérivé TRUE avec son produit raw FALSE est bloquant." if fr else "The canonical catalogue contains 17 survey/product pairs. In the operation 1 Shiny editor, only rows belonging to surveys whose status is TRUE are displayed; the example below therefore corresponds to RGB only. On save, hidden rows for FALSE surveys are automatically retained with status FALSE so product.csv remains a complete canonical file. Every product of each active survey is present: at least one is TRUE, a FALSE product produces a warning, and a derived TRUE product with its raw product FALSE is blocking."
    sections.append(section(f"{p}-4", "4. param/product.csv", f"<p>{product_text}</p>" + csv(PRODUCTS)))

    crown_rows = [
        ["path", "Chemin relatif depuis la racine du serveur jusqu’au crownfile. Les chemins absolus et les segments .. sont interdits." if fr else "Path from the server root to the crownfile. It must be relative; absolute paths and .. segments are forbidden."],
        ["server", "Alias portable du serveur contenant le crownfile. Sa racine locale est fournie à l’opération 3 et n’est jamais écrite dans config/." if fr else "Portable alias of the server containing the crownfile. Its local root is supplied to operation 3 and is never written in config/."],
        ["crownfile_type", "dynamic ou light." if fr else "dynamic or light."],
        ["plots_list", "TRUE/FALSE ; contrôle la présence de reference/plots_list.csv et l’obligation de plot_name." if fr else "TRUE/FALSE; controls reference/plots_list.csv and the plot_name requirement."],
        ["taxa_ref", "TRUE/FALSE ; contrôle la présence de reference/taxa_ref.csv et l’obligation de taxa_id." if fr else "TRUE/FALSE; controls reference/taxa_ref.csv and the taxa_id requirement."],
        ["dawkins", "TRUE/FALSE ; contrôle dawkins_param.csv, dawkins.csv et l’obligation de dawkins_code." if fr else "TRUE/FALSE; controls dawkins_param.csv, dawkins.csv, and the dawkins_code requirement."],
    ]
    crown_effect = """<ul><li>Le crownfile est toujours un fichier GeoPackage portant l’extension <code>.gpkg</code>.</li><li><code>dynamic</code> exige les couches geometry et infos ainsi que les variables <code>Tree_Status</code> et <code>Geom_Modif</code> dans geometry.</li><li><code>light</code> contient exactement une couche spatiale appelée <code>crowns</code> et n’exige pas ces deux variables. Toutes les lignes de crownfile_vars.csv portent alors <code>layer = crowns</code>.</li><li>Si <code>plots_list = TRUE</code>, un plot_name absent de plots_list.csv produit un warning.</li><li>Si <code>taxa_ref = TRUE</code>, taxa_id est obligatoire, mais ses valeurs ne sont pas comparées à taxa_ref.csv dans la 3.1.0. Si FALSE, taxa_id est facultatif et sa présence suggère, par warning, d’activer taxa_ref.</li><li>Si <code>dawkins = TRUE</code>, dawkins_code est obligatoire et contrôlé par dawkins.csv. Si FALSE, il est facultatif dans le crownfile et n’est pas contrôlé s’il est présent.</li></ul>""" if fr else """<ul><li>The crownfile is always a GeoPackage file with the <code>.gpkg</code> extension.</li><li><code>dynamic</code> requires the geometry and infos layers and requires <code>Tree_Status</code> and <code>Geom_Modif</code> in geometry.</li><li><code>light</code> contains exactly one spatial layer named <code>crowns</code> and does not require those two variables. Every crownfile_vars.csv row then has <code>layer = crowns</code>.</li><li>When <code>plots_list = TRUE</code>, a plot_name absent from plots_list.csv produces a warning.</li><li>When <code>taxa_ref = TRUE</code>, taxa_id is required, but its values are not compared with taxa_ref.csv in 3.1.0. When FALSE, taxa_id is optional and its presence triggers a warning suggesting taxa_ref.</li><li>When <code>dawkins = TRUE</code>, dawkins_code is required and checked against dawkins.csv. When FALSE, it is optional in the crownfile and is not checked if present.</li></ul>"""
    sections.append(section(f"{p}-5", "5. param/crownfile_param.csv", table(["Paramètre" if fr else "Parameter", "Valeur et conséquence" if fr else "Value and consequence"], crown_rows) + csv("""param;value
path;observatories/mbalmayo/crowns.gpkg
server;work
crownfile_type;dynamic
plots_list;TRUE
taxa_ref;FALSE
dawkins;TRUE""") + crown_effect))

    zoom_text = "Présent uniquement si tree_pictures = TRUE. Colonnes : sensor, zoom, zoom_type, effective_focal. Clé unique sensor/zoom/zoom_type. zoom commence par x suivi d’un entier sans espace. zoom_type vaut exactement native ou digital. effective_focal est un nombre décimal ; ne pas écrire l’unité dans le champ. Chaque sensor tree_pictures actuel ou historique possède au moins un zoom." if fr else "Present only when tree_pictures = TRUE. Columns: sensor, zoom, zoom_type, effective_focal. Unique key: sensor/zoom/zoom_type. zoom starts with x followed by an integer without spaces. zoom_type is exactly native or digital. effective_focal is decimal; do not write the unit in the field. Every current or historical tree_pictures sensor has at least one zoom."
    sections.append(section(f"{p}-6", "6. param/tree_picture_zooms.csv", f"<p>{zoom_text}</p>" + csv("""sensor;zoom;zoom_type;effective_focal
M3E;x14;digital;90.8
M3E;x7;native;45.4
M3E;x1;native;6.48""")))

    contributor_text = "Toujours obligatoire ; une seule colonne contributor. Les lignes vides et les doublons sont signalés ; Shiny les retire lors de la sauvegarde avec un warning. Une valeur creator du crownfile absente de cette table produit un warning." if fr else "Always required; one contributor column. Empty rows and duplicates are reported; Shiny removes them on save with a warning. A crownfile creator absent from this table produces a warning."
    sections.append(section(f"{p}-7", "7. reference/contributors.csv", f"<p>{contributor_text}</p>" + csv("""contributor
Nicolas Barbier
Pierre Ploton
Alex""")))

    plots_text = "Présent lorsque plots_list = TRUE. Une seule colonne plot_name, avec des valeurs uniques, non vides et sans espace. Un fichier manquant alors qu’il est activé, présent alors qu’il est désactivé, ou un plot_name du crownfile absent de la table produit un warning." if fr else "Present when plots_list = TRUE. One plot_name column with unique, non-empty values without spaces. A file missing while enabled, present while disabled, or a crownfile plot_name absent from the table produces a warning."
    sections.append(section(f"{p}-8", "8. reference/plots_list.csv", f"<p>{plots_text}</p>" + csv("""plot_name
mbalmayo001
mbalmayo002""")))

    dawkins_text = "Présent uniquement si dawkins = TRUE. Les 14 paramètres sont obligatoires et ordonnés. L’utilisateur modifie uniquement la colonne value. Toutes les valeurs sont numériques ; les valeurs négatives sont permises et aucune relation entre seuils n’est imposée. Elles serviront ultérieurement au calcul d’une des classes de reference/dawkins.csv ; l’algorithme d’attribution n’est pas exécuté dans la 3.1.0." if fr else "Present only when dawkins = TRUE. All 14 parameters are mandatory and ordered. The user changes only the value column. Every value is numeric; negative values are allowed and no relation between thresholds is enforced. They will later be used to calculate one of the reference/dawkins.csv classes; the assignment algorithm is not run in 3.1.0."
    sections.append(section(f"{p}-9", "9. param/dawkins_param.csv", f"<p>{dawkins_text}</p>" + csv(DAWKINS_PARAM) + ("<p><code>reference/dawkins.csv</code> est généré à l’étape 11 :</p>" if fr else "<p><code>reference/dawkins.csv</code> is generated at step 11:</p>") + csv(DAWKINS)))

    taxa_text = "Présent lorsque taxa_ref = TRUE. Le séparateur reste le point-virgule, mais les colonnes et valeurs sont libres. Aucun modèle de contenu n’est imposé actuellement dans la version 3.1.0 et aucune valeur taxa_id n’est comparée. L’absence lorsque le paramètre vaut TRUE ou la présence lorsqu’il vaut FALSE produit un warning." if fr else "Present when taxa_ref = TRUE. The separator remains a semicolon, but columns and values are unrestricted. No content model is currently imposed in version 3.1.0 and no taxa_id value is compared. Absence when the parameter is TRUE or presence when it is FALSE produces a warning."
    sections.append(section(f"{p}-10", "10. reference/taxa_ref.csv", f"<p>{taxa_text}</p>" + csv("""taxon_id;scientific_name
1289;Lophira alata""")))

    generated_rows = [
        ["param/crownfile_vars.csv", "Toujours ; construit depuis crownfile_type, plots_list, taxa_ref et dawkins." if fr else "Always; built from crownfile_type, plots_list, taxa_ref, and dawkins."],
        ["reference/dawkins.csv", "Si dawkins = TRUE." if fr else "When dawkins = TRUE."],
        ["reference/dbh_types.csv", "Toujours." if fr else "Always."],
        ["reference/geom_modif.csv", "Si crownfile_type = dynamic, lorsque Geom_Modif est exigée dans crownfile_vars.csv." if fr else "When crownfile_type = dynamic and Geom_Modif is required in crownfile_vars.csv."],
        ["reference/lianas.csv", "Toujours ; valeurs 0 et 1." if fr else "Always; values 0 and 1."],
        ["reference/tree_status.csv", "Si crownfile_type = dynamic." if fr else "When crownfile_type = dynamic."],
        ["reference/type_obs.csv", "Toujours." if fr else "Always."],
    ]
    generated_intro = "Ces tables sont produites par l’application et ne sont pas éditables. Toute différence avec leur modèle exigé est bloquante. Les exceptions de correspondance métier sont contributors.csv et plots_list.csv, qui produisent des warnings, ainsi que taxa_ref.csv, qui n’est pas contrôlé." if fr else "These tables are produced by the application and are not editable. Any difference from their required model is blocking. The business-reference exceptions are contributors.csv and plots_list.csv, which produce warnings, and taxa_ref.csv, which is not checked."
    generated_examples = (
        "<h3>param/crownfile_vars.csv — example dynamic schema with every option enabled</h3>" + csv(CROWNFILE_VARS) +
        "<h3>param/crownfile_vars.csv — example light schema without optional fields</h3>" + csv(CROWNFILE_VARS_LIGHT) +
        "<h3>reference/dawkins.csv</h3>" + csv(DAWKINS) +
        "<h3>reference/dbh_types.csv</h3>" + csv("""dbh_types
estimated
measured""") +
        "<h3>reference/geom_modif.csv</h3>" + csv("""Geom_Modif
Initial
Geometrical_Correction
Geometrical_Change""") +
        "<h3>reference/lianas.csv</h3>" + csv("""lianas
0
1""") +
        "<h3>reference/tree_status.csv</h3>" + csv("""Tree_Status
Alive
Dead
Fallen
Missing
Recruited""") +
        "<h3>reference/type_obs.csv</h3>" + csv("""Type_Obs
Field
Photo
Remote_sensing""")
    )
    if fr:
        generated_examples = generated_examples.replace("example dynamic schema with every option enabled", "exemple dynamic avec toutes les options activées")
    sections.append(section(f"{p}-11", "11. " + ("Fichiers générés automatiquement" if fr else "Automatically generated files"), table(["Fichier" if fr else "File", "Présence" if fr else "Presence"], generated_rows) + f"<p>{generated_intro}</p>" + generated_examples))

    folder_rows = [
        ["survey", "Survey canonique." if fr else "Canonical survey."],
        ["product", "Produit autorisé pour ce survey dans product.csv." if fr else "Product allowed for that survey in product.csv."],
        ["server", "Alias portable du serveur ; le chemin racine local est fourni seulement à l’opération 3." if fr else "Portable server alias; the local root is supplied only to operation 3."],
        ["path", "Chemin relatif sous la racine du serveur ; aucun chemin absolu ni segment .." if fr else "Relative path below the server root; no absolute path or .. segment."],
    ]
    folder_text = "Plusieurs emplacements sont autorisés pour un même couple survey/product, mais le quadruplet survey/product/server/path est unique. Un produit TRUE sans emplacement produit un warning. Un emplacement conservé pour un produit FALSE produit un warning. L’opération 1 vérifie la structure sans tester le chemin." if fr else "Several locations are allowed for one survey/product pair, but survey/product/server/path is unique. A TRUE product without a location produces a warning. A retained location for a FALSE product produces a warning. Operation 1 checks the structure without testing the path."
    sections.append(section(f"{p}-12", "12. path/UAV_folder.csv", table(["Colonne" if fr else "Column", "Signification et exigence" if fr else "Meaning and requirement"], folder_rows) + f"<p>{folder_text}</p>" + csv("""survey;product;server;path
RGB;RGB_raw;safe;PhenOBS_Africa/Survols_RGB/Mbalmayo
RGB;RGB_orthomosaic;work;shared/PhenOBS_Africa/Mbalmayo/ORTHO""")))

    pattern_rows = [
        ["survey", "Protocole canonique ; forme un couple autorisé avec product." if fr else "Canonical protocol; forms an allowed pair with product."],
        ["product", "Produit déclaré dans product.csv et, lorsqu’un emplacement existe, associé au même couple dans UAV_folder.csv." if fr else "Product declared in product.csv and, when a location exists, associated with the same pair in UAV_folder.csv."],
        ["directory_pattern", "Pattern appliqué aux noms des sous-dossiers immédiats. Remplir cette colonne ou filename_pattern, jamais les deux." if fr else "Pattern applied to immediate child directory names. Fill this column or filename_pattern, never both."],
        ["filename_pattern", "Pattern appliqué aux noms des fichiers immédiats. Remplir cette colonne ou directory_pattern, jamais les deux." if fr else "Pattern applied to immediate child file names. Fill this column or directory_pattern, never both."],
    ]
    pattern_intro = """<p>Ce fichier décrit <strong>comment les produits sont découverts sous chaque emplacement</strong>. Le scan de l’opération 3 est non récursif : un directory_pattern identifie un sous-dossier comme objet produit ; un filename_pattern identifie un fichier. Un pattern agit uniquement sur le nom immédiat et ne peut contenir ni <code>/</code> ni <code>\\</code>. Un couple survey/product apparaît au maximum une fois. Un couple actif ou configuré dans UAV_folder.csv sans pattern produit un warning ; un pattern conservé pour un produit FALSE produit aussi un warning.</p>
    <p>Chaque pattern RGB, MS ou DLS contient <strong>exactement un</strong> placeholder de date pris en charge. tree_pictures en est exempt. Les accolades sont équilibrées, les noms sont sensibles à la casse et un champ capturé ne peut apparaître qu’une fois.</p>""" if fr else """<p>This file defines <strong>how products are discovered below each configured location</strong>. The operation 3 scan is non-recursive: a directory_pattern identifies an immediate child directory as a product object; a filename_pattern identifies an immediate child file. A pattern acts on the immediate name only and cannot contain <code>/</code> or <code>\\</code>. A survey/product pair occurs at most once. An active pair or a pair configured in UAV_folder.csv without a pattern produces a warning; a retained pattern for a FALSE product also produces a warning.</p>
    <p>Every RGB, MS, or DLS pattern contains <strong>exactly one</strong> supported date placeholder. tree_pictures is exempt. Braces are balanced, names are case-sensitive, and a captured field can occur only once.</p>"""

    token_rows = [
        ["{product}", "Littéral fixe pris dans la colonne product ; non recapturé." if fr else "Fixed literal from the product column; not captured again."],
        ["{date}", "Date capturée yyyymmdd." if fr else "Captured yyyymmdd date."],
        ["{date:%Y-%m-%d}", "Date capturée YYYY-MM-DD puis normalisée en yyyymmdd." if fr else "Captured YYYY-MM-DD date normalized to yyyymmdd."],
        ["{date:%Y_%m_%d}", "Date capturée YYYY_MM_DD puis normalisée en yyyymmdd." if fr else "Captured YYYY_MM_DD date normalized to yyyymmdd."],
        ["{sensor}", "Sensor capturé ; comparé au survey et, si une date est capturée, à sa période inclusive dans sensor.csv." if fr else "Captured sensor; compared with the survey and, when a date is captured, its inclusive period in sensor.csv."],
        ["{site}", "Texte du site capturé depuis le nom de l’objet." if fr else "Site text captured from the object name."],
        ["<code>{site.&lt;param&gt;}</code>", "Valeur fixe de site.csv, par exemple <code>{site.id_site}</code> ; non capturée." if fr else "Fixed site.csv value, for example <code>{site.id_site}</code>; not captured."],
        ["{zoom}", "Zoom capturé ; autorisé uniquement pour tree_pictures." if fr else "Captured zoom; allowed only for tree_pictures."],
        ["{capture.picture_code}", "Code de prise de vue capturé." if fr else "Captured picture code."],
        ["<code>{crownfile.&lt;layer&gt;.&lt;var_name&gt;}</code>", "Variable crown capturée pour un crownfile dynamic ; layer et var_name doivent correspondre à crownfile_vars.csv." if fr else "Captured crown variable for a dynamic crownfile; layer and var_name must match crownfile_vars.csv."],
        ["<code>{crownfile.&lt;var_name&gt;}</code>", "Variable crown capturée pour un crownfile light ; var_name doit correspondre à crownfile_vars.csv." if fr else "Captured crown variable for a light crownfile; var_name must match crownfile_vars.csv."],
        ["{original_name}", "Nom d’origine capturé." if fr else "Captured original name."],
        ["{extension}", "Extension capturée." if fr else "Captured extension."],
        ["* et ?" if fr else "* and ?", "Jokers pour du texte libre ; aucune colonne créée." if fr else "Wildcards for unconstrained text; no output column."],
    ]
    transform_text = """<h3>Transformation explicite d’une valeur crown</h3>
    <pre><code>{crownfile.infos.tax_sp_level|space_to_hyphen}</code></pre>
    <p>Le suffixe <code>|space_to_hyphen</code> indique que les espaces ont été remplacés par des tirets dans le nom de l’objet. La convention transforme par exemple <code>Lophira alata</code> en <code>Lophira-alata</code> ; la découverte restitue les espaces dans la valeur capturée. Vérifier manuellement les noms scientifiques contenant des tirets significatifs.</p>""" if fr else """<h3>Explicit crown-value transformation</h3>
    <pre><code>{crownfile.infos.tax_sp_level|space_to_hyphen}</code></pre>
    <p>The <code>|space_to_hyphen</code> suffix declares that spaces were represented by hyphens in the object name. The convention turns <code>Lophira alata</code> into <code>Lophira-alata</code>; discovery restores spaces in the captured value. Review scientific names containing meaningful hyphens manually.</p>"""
    inventory_text = """<h3>Résultat de la découverte</h3><p>Chaque placeholder capturé devient une colonne de <code>all_products.csv</code>. Les colonnes standard sont toujours <code>survey</code>, <code>product</code>, <code>server</code>, <code>configured_path</code>, <code>relative_path</code>, <code>object_name</code> et <code>object_type</code>. Les racines absolues locales des serveurs ne sont jamais exportées. La colonne <code>exemple</code> de crownfile_vars.csv documente des valeurs crown représentatives ; la découverte lit les noms d’objets et ne modifie aucun fichier scientifique.</p>""" if fr else """<h3>Discovery result</h3><p>Every captured placeholder becomes a column in <code>all_products.csv</code>. The standard columns are always <code>survey</code>, <code>product</code>, <code>server</code>, <code>configured_path</code>, <code>relative_path</code>, <code>object_name</code>, and <code>object_type</code>. Absolute local server roots are never exported. The <code>exemple</code> column of crownfile_vars.csv documents representative crown values; discovery reads object names and never modifies scientific files.</p>"""
    pattern_example = csv("""survey;product;directory_pattern;filename_pattern
RGB;RGB_raw;{product}__{date}__{sensor};
RGB;RGB_orthomosaic;;{product}__{date}__{site}__ORTHO_aligned_local.tif
RGB;RGB_DEM;;{product}__{date}__{site}.tif
MS;MS_raw;{product}__{date}__{sensor};
MS;MS_orthomosaic;;{product}__{date}__{site}__ORTHO_aligned_local.tif
MS;MS_DEM;;{product}__{date}__{site}.tif
DLS;DLS_raw;{product}__{date}__{sensor};
DLS;DLS_CHM;;{product}__{date}__{sensor}.tif
DLS;DLS_DTM;;{product}__{date}__{sensor}.tif
tree_pictures;raw_tree_picture;{product}__{date}__{sensor};
tree_pictures;sorted_tree_picture;ID__{crownfile.infos.id}__{crownfile.infos.tax_sp_level};""")
    sections.append(section(f"{p}-13", "13. path/UAV_file_patterns.csv", table(["Colonne" if fr else "Column", "Signification et exigence" if fr else "Meaning and requirement"], pattern_rows) + pattern_intro + pattern_example + "<h3>" + ("Placeholders pris en charge" if fr else "Supported placeholders") + "</h3>" + table(["Placeholder", "Comportement" if fr else "Behaviour"], token_rows) + transform_text + inventory_text))

    vectors_text = "Cette section est encore en cours de construction. vectors.csv peut être créé vide ou rempli, mais son contenu n’est jamais lu, contrôlé, exporté dans observatory.yaml ou visualisé." if fr else "This section is still under construction. vectors.csv may be created empty or filled, but its contents are never read, checked, exported to observatory.yaml, or visualised."
    sections.append(section(f"{p}-14", "14. path/vectors.csv", f"<p>{vectors_text}</p>"))

    yaml_rows = [
        ["Ordre" if fr else "Order", "Une section par CSV suit l’ordre des étapes ; la première propriété est path." if fr else "One section per CSV follows step order; the first property is path."],
        ["Fichiers conditionnels" if fr else "Conditional files", "La section est toujours incluse avec status: activated ou status: non activated." if fr else "The section is always included with status: activated or status: non activated."],
        ["Exclusions", "taxa_ref.csv et vectors.csv ne sont pas inclus." if fr else "taxa_ref.csv and vectors.csv are not included."],
        ["Rapport HTML" if fr else "HTML report", "{site.name}_observatory_infos.html est bilingue, autonome et hors ligne. Un tableau optionnel absent du dossier config n’y apparaît pas. Les espaces du nom deviennent _, les apostrophes sont supprimées et les accents sont interdits dans site.name." if fr else "{site.name}_observatory_infos.html is bilingual, standalone, and offline. An optional table absent from the config folder is omitted. Name spaces become _, apostrophes are removed, and accents are forbidden in site.name."],
        ["site_check.txt", "Regroupe warnings et erreurs dans l’ordre du dossier config ; un fichier sans diagnostic est omis. Les constats non attribuables figurent sous GLOBAL." if fr else "Groups warnings and errors in config order; files without diagnostics are omitted. Unassignable findings appear under GLOBAL."],
        ["Archive", "Avant une nouvelle publication valide, observatory.yaml et site_check.txt existants sont déplacés dans archive/ et renommés avec before_yyyymmdd[_n]." if fr else "Before a new valid publication, existing observatory.yaml and site_check.txt are moved to archive/ and renamed with before_yyyymmdd[_n]."],
        ["Rapport de modification" if fr else "Modification report", "modification_yyyymmdd[_n].txt liste les fichiers modifiés, créés et supprimés, leurs contenus avant/après et leurs conséquences. Les contenus CSV sont bruts et directement copiables. Les modifications de observatory.yaml sont placées après tous les autres fichiers ; ses blocs avant/après sont également bruts et copiables. Le rapport HTML du site, entièrement dérivé, n’est jamais mentionné. Le rapport actif précédent est déplacé dans archive/ sans être renommé." if fr else "modification_yyyymmdd[_n].txt lists modified, created, and deleted files, their before/after contents, and their consequences. CSV contents are raw and directly copyable. Changes to observatory.yaml are placed after every other file; its before/after blocks are also raw and copyable. The fully derived site HTML report is never mentioned. The previous active report is moved to archive/ without renaming."],
    ]
    yaml_example = csv("""schema_version: 3.1.0
date_format: yyyymmdd
site:
  path: config/param/site.csv
  data: [...]
tree_picture_zooms:
  path: config/param/tree_picture_zooms.csv
  status: non activated
  data: []""")
    sections.append(section(f"{p}-15", "15. observatory.yaml " + ("et rapports de configuration" if fr else "and configuration reports"), table(["Élément" if fr else "Item", "Règle" if fr else "Rule"], yaml_rows) + yaml_example))
    return "".join(sections)


def appendices(lang):
    fr = lang == "fr"
    p = "fr" if fr else "en"
    inventory_rows = [
        ["all_products.csv", "Inventaire écrit ou actualisé sur demande après un contrôle connecté réussi, même si celui-ci contient uniquement des warnings." if fr else "Inventory written or updated on request after a successful connected check, including a check with warnings only."],
        ["products_check.txt", "Diagnostics écrits automatiquement à chaque scan de l’inventaire des produits puis actualisés avec all_products.csv." if fr else "Diagnostics written automatically for every product-inventory scan and refreshed with all_products.csv."],
        ["site_check.txt", "Diagnostics de configuration regroupés par fichier." if fr else "Configuration diagnostics grouped by file."],
    ]
    consistency_rows = [
        ["survey → sensor", "Chaque survey actif a un sensor ; aucun sensor pour un survey FALSE." if fr else "Every active survey has a sensor; FALSE surveys have no sensor row."],
        ["survey → product", "Toutes les lignes du catalogue existent ; surveys inactifs uniquement FALSE ; chaque survey actif a un produit TRUE." if fr else "Every catalog row exists; inactive surveys have only FALSE products; every active survey has a TRUE product."],
        ["product → UAV", "Dossier ou pattern manquant pour un produit actif : warning ; mapping inactif conservé : warning." if fr else "Missing folder or pattern for an active product: warning; retained inactive mapping: warning."],
        ["survey → zooms", "tree_pictures contrôle le fichier de zoom ; chaque sensor tree_pictures a au moins un zoom." if fr else "tree_pictures controls the zoom file; every tree_pictures sensor has at least one zoom."],
        ["crownfile_param → crownfile", "server et path localisent le fichier ; crownfile_type, plots_list, taxa_ref et dawkins déterminent son schéma obligatoire." if fr else "server and path locate the file; crownfile_type, plots_list, taxa_ref, and dawkins determine its mandatory schema."],
        ["configuration → YAML/HTML", "Toute modification impose une nouvelle publication ; aucune donnée scientifique n’est modifiée." if fr else "Every change requires publication again; no scientific data are modified."],
        ["dynamic → dates", "Si RGB et RGB_orthomosaic sont actifs, les dates du crownfile sont comparées aux orthomosaïques observées ; absence : warning." if fr else "When RGB and RGB_orthomosaic are active, crown dates are compared with observed orthomosaics; absence: warning."],
    ]
    migration = "Shiny compare simultanément la version publiée et la version candidate ; les cellules modifiées, lignes supprimées et lignes ajoutées sont colorées. config_change_impacts() décrit les fichiers dépendants à créer, remplir ou vérifier. En R direct, operation2_modify_config(), preview_config_table_change() et generate_config_outputs(before_snapshot = ...) fournissent les mêmes informations. Après une validation globale réussie, la publication archive les anciens observatory.yaml et site_check.txt, déplace le rapport de modification actif dans archive/ sans le renommer, reconstruit les sorties et écrit modification_yyyymmdd[_n].txt. Les blocs CSV avant/après restent bruts. Les blocs YAML, également bruts, sont regroupés à la fin ; le rapport HTML dérivé est exclu du journal. Les suffixes _2, _3, etc. empêchent toute collision le même jour. Aucune donnée scientifique n’est modifiée." if fr else "Shiny compares the published and candidate versions simultaneously; modified cells, deleted rows, and added rows are coloured. config_change_impacts() describes dependent files to create, fill, or check. In direct R use, operation2_modify_config(), preview_config_table_change(), and generate_config_outputs(before_snapshot = ...) provide the same information. After successful global validation, publication archives the previous observatory.yaml and site_check.txt, moves the active modification report into archive/ without renaming it, rebuilds outputs, and writes modification_yyyymmdd[_n].txt. Before/after CSV blocks remain raw. YAML blocks are also raw and grouped at the end; the derived HTML report is excluded from the log. The _2, _3, and later suffixes prevent same-day collisions. Scientific data are never modified."
    comparison = "<p><code>compare_raw_processed()</code> produit une ligne par survey, date et produit traité. Avec <code>group_by_processed_status = TRUE</code>, il additionne raw_count et processed_count pour chaque couple processed_product/status. Les statuts sont completed, missing_processed et processed_without_raw. Dans Shiny, cette comparaison est proposée après un contrôle réussi ; les tableaux interactifs possèdent un filtre par colonne.</p>" if fr else "<p><code>compare_raw_processed()</code> returns one row per survey, date, and processed product. With <code>group_by_processed_status = TRUE</code>, it sums raw_count and processed_count for each processed_product/status pair. Status values are completed, missing_processed, and processed_without_raw. Shiny offers this comparison after a successful check; interactive tables have one filter per column.</p>"
    reserves = "<ul><li>Les colonnes et la sémantique de vectors.csv ne sont pas définies ; son contenu est ignoré.</li><li>taxa_ref.csv n’a pas de modèle de contenu et les valeurs taxa_id ne sont pas comparées dans la 3.1.0.</li><li>Les paramètres Dawkins sont stockés et contrôlés, mais l’algorithme d’attribution des classes n’est pas exécuté.</li></ul>" if fr else "<ul><li>The columns and semantics of vectors.csv are not defined; its contents are ignored.</li><li>taxa_ref.csv has no content model and taxa_id values are not compared in 3.1.0.</li><li>Dawkins parameters are stored and checked, but the class-assignment algorithm is not run.</li></ul>"
    return (
        section(f"{p}-a", "A. " + ("Fichiers d’inventaire" if fr else "Inventory files"), table(["Fichier" if fr else "File", "Rôle" if fr else "Purpose"], inventory_rows) + comparison) +
        section(f"{p}-b", "B. " + ("Cohérence exigée entre les fichiers" if fr else "Required consistency between files"), table(["Source", "Cohérence exigée" if fr else "Required consistency"], consistency_rows)) +
        section(f"{p}-c", "C. " + ("Évolution d’une configuration" if fr else "Configuration evolution"), f"<p>{migration}</p>") +
        section(f"{p}-d", "D. " + ("Fonctionnalités réservées" if fr else "Reserved functions"), reserves)
    )


TOC_EN = [
    ("en-0", "0. General conventions"), ("en-1", "1. site.csv"), ("en-2", "2. survey.csv"),
    ("en-3", "3. sensor.csv"), ("en-4", "4. product.csv"), ("en-5", "5. crownfile_param.csv"),
    ("en-6", "6. tree_picture_zooms.csv"), ("en-7", "7. contributors.csv"),
    ("en-8", "8. plots_list.csv"), ("en-9", "9. dawkins_param.csv"), ("en-10", "10. taxa_ref.csv"),
    ("en-11", "11. Generated files"), ("en-12", "12. UAV_folder.csv"),
    ("en-13", "13. UAV_file_patterns.csv"), ("en-14", "14. vectors.csv"),
    ("en-15", "15. YAML and reports"), ("en-a", "A. Inventory"), ("en-b", "B. Consistency"),
    ("en-c", "C. Evolution"), ("en-d", "D. Reserved"),
]

TOC_FR = [
    ("fr-0", "0. Conventions générales"), ("fr-1", "1. site.csv"), ("fr-2", "2. survey.csv"),
    ("fr-3", "3. sensor.csv"), ("fr-4", "4. product.csv"), ("fr-5", "5. crownfile_param.csv"),
    ("fr-6", "6. tree_picture_zooms.csv"), ("fr-7", "7. contributors.csv"),
    ("fr-8", "8. plots_list.csv"), ("fr-9", "9. dawkins_param.csv"), ("fr-10", "10. taxa_ref.csv"),
    ("fr-11", "11. Fichiers générés"), ("fr-12", "12. UAV_folder.csv"),
    ("fr-13", "13. UAV_file_patterns.csv"), ("fr-14", "14. vectors.csv"),
    ("fr-15", "15. YAML et rapports"), ("fr-a", "A. Inventaire"), ("fr-b", "B. Cohérence"),
    ("fr-c", "C. Évolution"), ("fr-d", "D. Réserves"),
]


def language_page(lang):
    toc = TOC_FR if lang == "fr" else TOC_EN
    links = "".join(f"<a href='#{anchor}'>{label}</a>" for anchor, label in toc)
    title = "Guide des fichiers de configuration" if lang == "fr" else "Configuration files guide"
    label = "Sommaire" if lang == "fr" else "Contents"
    return f"""<div id='{lang}-page' class='language-page'{' hidden' if lang == 'fr' else ''}>
    <div class='guide-shell'>
      <aside class='toc' aria-label='{label}'><h2>{label}</h2>{links}</aside>
      <main><h1>{title}</h1><p class='lede'>canObsR — schema 3.1.0</p>{general(lang)}{steps(lang)}{appendices(lang)}</main>
    </div></div>"""


document = f"""<!doctype html>
<html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>
<title>canObsR 3.1.0 — Configuration files guide</title>
<style>
:root{{--green:#217346;--green-dark:#123f2f;--ink:#17342a;--muted:#5d7169;--line:#d9e5de;--paper:#fff;--bg:#f4f7f5}}
*{{box-sizing:border-box}}html{{scroll-behavior:smooth}}body{{margin:0;font-family:Inter,system-ui,-apple-system,sans-serif;color:var(--ink);background:var(--bg);line-height:1.58}}
.topbar{{position:sticky;top:0;z-index:20;display:flex;justify-content:space-between;align-items:center;gap:16px;padding:12px max(18px,calc((100vw - 1500px)/2));background:linear-gradient(135deg,var(--green-dark),var(--green));color:#fff;box-shadow:0 2px 10px rgba(12,46,33,.18)}}
.brand{{font-weight:800;letter-spacing:.01em}}button{{background:#fff;color:var(--green);border:0;border-radius:8px;padding:9px 14px;font-weight:800;cursor:pointer}}
[hidden]{{display:none!important}}.guide-shell{{max-width:1500px;margin:auto;display:grid;grid-template-columns:280px minmax(0,1fr);gap:24px;padding:24px}}
.toc{{position:sticky;top:78px;align-self:start;max-height:calc(100vh - 98px);overflow:auto;background:#fff;border:1px solid var(--line);border-radius:12px;padding:16px}}
.toc h2{{font-size:1rem;margin:0 0 8px;border:0;padding:0}}.toc a{{display:block;color:var(--green);text-decoration:none;padding:5px 7px;border-radius:6px;font-size:.9rem}}.toc a:hover{{background:#e7f4ec}}
main{{min-width:0}}main>h1{{margin:0;font-size:clamp(2rem,5vw,3.1rem)}}.lede{{margin:0 0 24px;color:var(--muted)}}
section{{scroll-margin-top:78px;background:var(--paper);border:1px solid var(--line);border-radius:13px;padding:24px;margin:0 0 20px;box-shadow:0 4px 16px rgba(14,50,36,.04)}}
h2{{margin-top:0;border-bottom:2px solid #e7f4ec;padding-bottom:10px}}h3{{margin-top:28px}}code{{font-family:ui-monospace,SFMono-Regular,Menlo,monospace}}pre{{background:#10271f;color:#e5fff0;padding:16px;border-radius:9px;overflow:auto;line-height:1.45}}
.table-wrap{{overflow:auto;margin:14px 0}}table{{width:100%;border-collapse:collapse}}th,td{{text-align:left;vertical-align:top;padding:9px 11px;border-bottom:1px solid #e6ece8}}th{{background:#edf6f0}}ul{{padding-left:22px}}
@media(max-width:900px){{.guide-shell{{grid-template-columns:1fr;padding:14px}}.toc{{position:static;max-height:none;columns:2}}.toc h2{{column-span:all}}}}
@media(max-width:560px){{.toc{{columns:1}}section{{padding:17px}}}}
@media print{{.topbar,.toc{{display:none}}body{{background:#fff}}.guide-shell{{display:block;padding:0}}section{{box-shadow:none;break-inside:avoid}}}}
</style></head><body>
<div class='topbar'><div class='brand'>canObsR · 3.1.0</div><button id='language' type='button'>Français</button></div>
{language_page('en')}{language_page('fr')}
<script>
(function(){{
  var button=document.getElementById('language');
  var en=document.getElementById('en-page');
  var fr=document.getElementById('fr-page');
  function show(language){{
    var french=language==='fr';
    en.hidden=french; fr.hidden=!french;
    document.documentElement.lang=french?'fr':'en';
    button.textContent=french?'English':'Français';
    try{{localStorage.setItem('canobs-guide-language',french?'fr':'en')}}catch(e){{}}
  }}
  button.addEventListener('click',function(){{show(document.documentElement.lang==='fr'?'en':'fr')}});
  var saved='en'; try{{saved=localStorage.getItem('canobs-guide-language')||'en'}}catch(e){{}}
  show(saved==='fr'?'fr':'en');
}})();
</script></body></html>"""

DESTINATION.parent.mkdir(parents=True, exist_ok=True)
DESTINATION.write_text(document, encoding="utf-8")
print(DESTINATION)
