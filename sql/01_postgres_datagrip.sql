-- ============================================================================================
-- TP « Sources de données » (AMA) — 01 · PostgreSQL en SQL pur — script DataGrip
--
-- Cas d'usage : la direction d'un réseau de 24 écoles (France, Bénin, Sénégal) prépare son
-- conseil d'administration. Elle veut un premier état des lieux chiffré de l'année scolaire
-- 2025-2026 : nombre d'écoles, de classes et d'élèves inscrits par pays, et moyenne générale
-- du 1er trimestre. Livrable : un tableau de bord par pays (partie 10).
--
-- COMMENT UTILISER CE FICHIER DANS DATAGRIP
-- 1. Créez la connexion (Data Source PostgreSQL) en suivant la fiche
--    docs/connexion_datagrip.md (port 6543, prepareThreshold = 0, sslmode = require).
-- 2. Ouvrez ce fichier (File > Open) et attachez-le à la data source : sélecteur en haut à
--    droite de l'éditeur, ou choix proposé au premier lancement.
-- 3. Placez le curseur dans une requête et appuyez sur Ctrl+Entrée (Cmd+Entrée sur macOS) :
--    seule cette requête est exécutée, le résultat s'affiche en bas.
-- 4. Avancez dans l'ordre. Les lignes qui commencent par « -- » sont des commentaires : ce
--    sont les explications, PostgreSQL les ignore.
-- 5. Exercices : lisez l'énoncé « ✍️ », essayez d'écrire la requête vous-même dans une console
--    (clic droit sur la data source > New > Query Console), puis comparez avec la solution
--    « ✅ ».
--
-- SCHÉMA : le schéma complet et commenté de la base (clés, contraintes, index) est dans
-- docs/schema_postgres.sql (à lire, pas à exécuter).
--
-- RÈGLES : la base est partagée par toute la promotion et ce TP est en LECTURE SEULE :
-- uniquement des SELECT (jamais INSERT, UPDATE, DELETE, CREATE, DROP). Toujours un LIMIT ou un
-- filtre (la table notes contient plus d'un million de lignes).
--
-- Le même contenu existe en notebook Jupyter : notebooks/01_postgres_sql.ipynb
-- ============================================================================================


-- ===== 0. Se connecter à la base =====
-- Dans DataGrip, la connexion se règle une fois pour toutes, sans code : suivez la fiche
-- docs/connexion_datagrip.md (hôte du pooler Supabase, port 6543, base postgres,
-- prepareThreshold = 0, sslmode = require).
--
-- 💡 Pooler : notre base est hébergée chez Supabase et passe par un « pooler », un
-- intermédiaire qui partage quelques connexions entre tous les étudiants (port 6543, mode
-- « transaction »). Ce mode ne supporte pas les requêtes préparées à l'avance : c'est pourquoi
-- on règle prepareThreshold = 0 dans le driver JDBC.

-- --- 0.1 · Première requête : la base répond-elle ? ---
-- version() est une fonction de PostgreSQL qui renvoie la version du serveur. Si vous voyez
-- une ligne commençant par « PostgreSQL 17 », la connexion fonctionne.
SELECT version();


-- ===== 1. Se repérer dans la base =====
-- Avant toute question « métier », on fait le tour du propriétaire. PostgreSQL est un SGBD
-- relationnel (système de gestion de base de données) : il range les données dans des tables,
-- c'est-à-dire des tableaux avec une ligne par enregistrement (une école, un élève…) et une
-- colonne par information (nom, date…). Les tables sont regroupées dans des schémas (des
-- sortes de dossiers) : les nôtres sont dans le schéma public.
--
-- PostgreSQL décrit sa propre structure dans un catalogue nommé information_schema, que l'on
-- interroge… avec du SQL.

-- --- 1.1 · Les tables et les vues du schéma public ---
-- Une requête se lit presque comme une phrase : SELECT (les colonnes voulues) FROM (la table)
-- WHERE (la condition) ORDER BY (l'ordre du résultat). Un texte entre apostrophes, comme
-- 'public', est une valeur. Le point-virgule ; termine la requête.
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_type, table_name;
-- 15 tables (BASE TABLE) et 2 vues (VIEW, voir partie 9). Les noms parlent d'eux-mêmes : pays,
-- villes, ecoles, classes, eleves, inscriptions, bulletins, notes…

-- --- 1.2 · Les colonnes d'une table ---
-- Quelles informations a-t-on sur une école ? information_schema.columns liste les colonnes de
-- chaque table avec leur type : integer (nombre entier), character varying (texte), date,
-- numeric (nombre décimal), boolean (vrai/faux), timestamp (date + heure).
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'ecoles'
ORDER BY ordinal_position;

-- --- 1.3 · Combien de lignes ? Le réflexe COUNT(*) ---
-- Réflexe n°1 avant de récupérer des données : compter. COUNT(*) renvoie le nombre de lignes
-- d'une table sans les transférer : c'est le serveur qui compte, seul le résultat (un nombre)
-- voyage sur le réseau. AS nb_notes donne un nom, un alias, à la colonne du résultat.
SELECT COUNT(*) AS nb_notes
FROM notes;
-- Plus de 1,18 million de notes : on n'écrira jamais SELECT * FROM notes sans filtre ni LIMIT,
-- surtout à 30 sur la même base.

-- --- 1.4 · Le volume de plusieurs tables d'un coup ---
-- Chaque parenthèse est une petite requête qui renvoie un seul nombre ; on les place côte à
-- côte dans un même SELECT pour obtenir une ligne de synthèse.
SELECT (SELECT COUNT(*) FROM pays)    AS nb_pays,
       (SELECT COUNT(*) FROM villes)  AS nb_villes,
       (SELECT COUNT(*) FROM ecoles)  AS nb_ecoles,
       (SELECT COUNT(*) FROM classes) AS nb_classes,
       (SELECT COUNT(*) FROM eleves)  AS nb_eleves;
-- 3 pays, 12 villes, 24 écoles. Les 1 306 classes couvrent 7 années scolaires (de 2019-2020 à
-- 2025-2026) : pour notre mission, il faudra filtrer sur 2025-2026.

-- Comment les tables sont reliées. Chaque table a une clé primaire id : un numéro unique par
-- ligne. Une clé étrangère est une colonne qui contient l'id d'une ligne d'une autre table :
-- par exemple, villes.pays_id contient l'id du pays de la ville. Ce sont ces clés qui
-- permettront de relier les tables (partie 6). Les liens utiles pour la mission :
--
--   pays ──< villes ──< ecoles ──< classes ──< inscriptions >── eleves
--           (pays_id)  (ville_id)  (ecole_id)  (classe_id, eleve_id, annee_scolaire_id)
--
--   bulletins        : une ligne par élève, par année et par trimestre
--                      (moyenne_generale, rang, appreciation)
--   annees_scolaires : de 2019-2020 à 2025-2026
--
-- Lisez ──< comme « un… pour plusieurs… » : un pays a plusieurs villes, une ville a plusieurs
-- écoles, une école a plusieurs classes, etc. Le symbole >── est le même lien dans l'autre
-- sens : un élève a plusieurs inscriptions (une par année). Entre parenthèses, sous chaque
-- table : la clé étrangère qu'elle contient.
--
-- 💡 Le schéma complet et commenté (clés, contraintes, index) est dans le fichier
-- docs/schema_postgres.sql du dépôt : à lire, pas à exécuter. Dans DataGrip, clic droit sur le
-- schéma public → Diagrams → Show Diagram dessine aussi toutes les tables et leurs liens.


-- ===== 2. SELECT : choisir les colonnes =====
-- SELECT est la commande de lecture. On choisit les colonnes à afficher, on peut les renommer
-- ou en calculer de nouvelles, et on limite le nombre de lignes reçues.

-- --- 2.1 · Toute une (petite) table ---
-- * signifie « toutes les colonnes ». C'est pratique pour découvrir une petite table comme
-- pays (3 lignes), à éviter sur les grosses tables.
SELECT *
FROM pays;

-- --- 2.2 · Quelques colonnes, quelques lignes ---
-- Sur une table plus grande, on nomme les colonnes utiles et on ajoute LIMIT n pour ne
-- recevoir que n lignes : c'est rapide et cela ménage le serveur partagé.
SELECT nom, type_ecole, niveau_ecole, capacite_max
FROM ecoles
LIMIT 5;

-- --- 2.3 · Renommer et calculer une colonne ---
-- AS renomme une colonne du résultat. On peut aussi calculer une colonne : l'opérateur ||
-- colle deux textes bout à bout.
--
-- Remarquez qu'on ne sélectionne ni l'e-mail ni le téléphone des parents : on ne prend que ce
-- dont la mission a besoin. C'est le principe de minimisation du RGPD vu en cours (les noms de
-- cette base sont fictifs, mais on garde le bon réflexe).
SELECT prenom || ' ' || nom AS eleve,
       date_naissance       AS ne_le,
       nationalite
FROM eleves
LIMIT 5;


-- ===== 3. WHERE : filtrer les lignes =====
-- WHERE ne garde que les lignes qui respectent une condition. Les textes et les dates
-- s'écrivent entre apostrophes '...', les nombres sans. Les opérateurs à connaître :
-- - = égal, <> différent, <, >, <=, >= ;
-- - IN (...) : la valeur fait partie d'une liste ;
-- - BETWEEN a AND b : entre deux bornes, incluses ;
-- - LIKE / ILIKE : le texte ressemble à un motif ;
-- - IS NULL : la valeur est absente ;
-- - AND, OR : combiner plusieurs conditions.

-- --- 3.1 · L'année scolaire en cours ---
-- La colonne est_active est un booléen (true = vrai, false = faux). Quelle année scolaire est
-- en cours ?
SELECT id, libelle, date_debut, date_fin
FROM annees_scolaires
WHERE est_active = true;
-- 💡 Retenez : l'année 2025-2026 a l'identifiant 7. Les tables classes, inscriptions et
-- bulletins ont une colonne annee_scolaire_id : pour la mission, on filtrera avec
-- annee_scolaire_id = 7.

-- --- 3.2 · Égal à un texte ---
-- Les écoles privées du réseau. Attention, la valeur stockée est exactement 'prive', sans
-- accent : en SQL, 'privé' ne donnerait aucune ligne. La partie 4 montre comment lister les
-- valeurs possibles d'une colonne.
SELECT nom, type_ecole, niveau_ecole
FROM ecoles
WHERE type_ecole = 'prive';

-- --- 3.3 · Différent de, et deux conditions ---
-- Les lycées qui ne sont pas publics : avec AND, les deux conditions doivent être vraies en
-- même temps.
SELECT nom, type_ecole, capacite_max
FROM ecoles
WHERE niveau_ecole = 'lycee'
  AND type_ecole <> 'public';

-- --- 3.4 · Une liste de valeurs (IN) ---
-- Trois grandes villes du réseau, une par pays. IN évite d'écrire nom = 'Paris' OR nom =
-- 'Cotonou' OR nom = 'Dakar'.
SELECT id, nom, pays_id
FROM villes
WHERE nom IN ('Paris', 'Cotonou', 'Dakar');

-- --- 3.5 · Un intervalle (BETWEEN) ---
-- Les écoles qui ont entre 400 et 600 places (bornes incluses).
SELECT nom, capacite_max
FROM ecoles
WHERE capacite_max BETWEEN 400 AND 600;

-- --- 3.6 · Un motif de texte (LIKE, ILIKE) ---
-- LIKE compare un texte à un motif où % remplace n'importe quelle suite de caractères (et _ un
-- seul caractère). LIKE distingue majuscules et minuscules ; ILIKE (propre à PostgreSQL) ne
-- les distingue pas. Le nom de chaque école se termine par sa ville : cherchons les écoles de
-- Dakar.
SELECT nom
FROM ecoles
WHERE nom ILIKE '%dakar%';

-- --- 3.7 · Les valeurs manquantes (IS NULL) ---
-- NULL signifie « valeur absente ou inconnue ». Ce n'est pas une valeur comme les autres :
-- motif = NULL ne trouve rien, il faut écrire motif IS NULL (ou IS NOT NULL). Combien
-- d'absences n'ont aucun motif renseigné ?
SELECT COUNT(*) AS absences_sans_motif
FROM absences
WHERE motif IS NULL;

-- --- 3.8 · Combiner AND et OR (avec des parenthèses) ---
-- Les absences « à vérifier » : sans motif ou pour voyage, et non justifiées. Les parenthèses
-- indiquent ce qui va ensemble, comme en calcul.
SELECT COUNT(*) AS absences_a_verifier
FROM absences
WHERE (motif IS NULL OR motif = 'Voyage')
  AND justifiee = false;
-- ⚠️ Sans les parenthèses, AND est évalué avant OR et la question devient « sans motif
-- (justifiées ou non), ou bien pour voyage et non justifiées » : on obtient 5 573 lignes au
-- lieu de 3 191. Essayez !

-- ✍️ Exercice 1 : Les écoles primaires publiques
-- La direction veut la liste des écoles primaires et publiques, avec leur nombre de places
-- (capacite_max). Colonnes utiles : niveau_ecole et type_ecole.

-- ✅ Solution
SELECT nom, capacite_max
FROM ecoles
WHERE niveau_ecole = 'primaire'
  AND type_ecole = 'public';


-- ===== 4. ORDER BY et DISTINCT : trier et dédoublonner =====
-- Sans ORDER BY, l'ordre des lignes n'est pas garanti : il peut changer d'une exécution à
-- l'autre. ORDER BY colonne trie du plus petit au plus grand (ASC, par défaut) ; DESC inverse
-- l'ordre. Combiné avec LIMIT, on obtient un « top n ».

-- --- 4.1 · Les 5 plus grandes écoles ---
-- On trie par capacité décroissante et on garde les 5 premières lignes.
SELECT nom, capacite_max
FROM ecoles
ORDER BY capacite_max DESC
LIMIT 5;

-- --- 4.2 · Trier sur plusieurs colonnes ---
-- D'abord par type d'école, puis par nom à l'intérieur de chaque type.
SELECT type_ecole, nom
FROM ecoles
ORDER BY type_ecole, nom
LIMIT 10;

-- --- 4.3 · Les valeurs distinctes d'une colonne ---
-- DISTINCT supprime les doublons du résultat : pratique pour connaître les valeurs possibles
-- d'une colonne avant d'écrire un filtre.
SELECT DISTINCT type_ecole
FROM ecoles
ORDER BY type_ecole;

-- --- 4.4 · DISTINCT et les NULL ---
-- Les motifs d'absence possibles : le NULL apparaît comme une valeur à part entière, en
-- dernier (PostgreSQL range les NULL après les autres valeurs). Il s'affiche None dans le
-- notebook et <null> dans DataGrip.
SELECT DISTINCT motif
FROM absences
ORDER BY motif;

-- ✍️ Exercice 2 : Les combinaisons type / niveau
-- Quelles combinaisons (type_ecole, niveau_ecole) existent dans le réseau ? Affichez chaque
-- combinaison une seule fois, triée par type puis par niveau. Indice : DISTINCT s'applique à
-- l'ensemble des colonnes du SELECT.

-- ✅ Solution
SELECT DISTINCT type_ecole, niveau_ecole
FROM ecoles
ORDER BY type_ecole, niveau_ecole;
-- Les 9 combinaisons existent : chaque type d'école (public, privé, communautaire) est présent
-- aux trois niveaux.
--
-- 💡 Le schéma (docs/schema_postgres.sql) autorise aussi le niveau 'mixte', mais aucune école
-- ne l'utilise : le schéma dit ce qui est possible, seules les données disent ce qui existe.


-- ===== 5. Agrégats : COUNT, AVG, MIN, MAX, GROUP BY, HAVING =====
-- Une fonction d'agrégat résume plusieurs lignes en une seule valeur : COUNT (nombre), SUM
-- (somme), AVG (moyenne), MIN, MAX. ROUND(x, 2) arrondit à 2 décimales. C'est le cœur d'un
-- état des lieux chiffré… et c'est le serveur qui calcule : seul le résultat voyage sur le
-- réseau.

-- --- 5.1 · Résumer toute une table ---
-- Sans GROUP BY, l'agrégat porte sur toute la table : on obtient une seule ligne.
SELECT COUNT(*)                    AS nb_ecoles,
       MIN(capacite_max)           AS plus_petite,
       MAX(capacite_max)           AS plus_grande,
       ROUND(AVG(capacite_max), 1) AS capacite_moyenne
FROM ecoles;

-- --- 5.2 · Un résumé par groupe (GROUP BY) ---
-- GROUP BY forme des groupes de lignes qui ont la même valeur, puis calcule l'agrégat dans
-- chaque groupe. Règle d'or : toute colonne du SELECT qui n'est pas dans un agrégat doit
-- figurer dans le GROUP BY.
SELECT type_ecole, COUNT(*) AS nb_ecoles
FROM ecoles
GROUP BY type_ecole
ORDER BY nb_ecoles DESC;

-- --- 5.3 · La moyenne générale par trimestre en 2025-2026 ---
-- La table bulletins contient la moyenne_generale de chaque élève à chaque trimestre. On garde
-- l'année 2025-2026 (annee_scolaire_id = 7, vu en partie 3), puis on regroupe par trimestre.
SELECT trimestre,
       COUNT(*)                        AS nb_bulletins,
       ROUND(AVG(moyenne_generale), 2) AS moyenne
FROM bulletins
WHERE annee_scolaire_id = 7
GROUP BY trimestre
ORDER BY trimestre;
-- 2 209 bulletins par trimestre, soit un par élève inscrit cette année. Moyenne du 1er
-- trimestre : 10,92/20. Gardez ces deux chiffres en tête : nous les recouperons avec le
-- tableau de bord final.

-- --- 5.4 · Filtrer les groupes (HAVING) ---
-- WHERE filtre les lignes avant le regroupement ; HAVING filtre les groupes après le calcul.
-- Quelles classes de 2025-2026 comptent plus de 40 élèves inscrits ?
SELECT classe_id, COUNT(*) AS nb_inscrits
FROM inscriptions
WHERE annee_scolaire_id = 7
GROUP BY classe_id
HAVING COUNT(*) > 40
ORDER BY nb_inscrits DESC, classe_id;
-- La classe n°597 compte 63 élèves : c'est beaucoup ! Nous la retrouverons dans les parties 9
-- et 11.

-- ✍️ Exercice 3 : Les spécialités les plus représentées
-- Comptez les enseignants (table enseignants) par specialite et ne gardez que les spécialités
-- qui ont au moins 25 enseignants, de la plus représentée à la moins représentée.

-- ✅ Solution
SELECT specialite, COUNT(*) AS nb_enseignants
FROM enseignants
GROUP BY specialite
HAVING COUNT(*) >= 25
ORDER BY nb_enseignants DESC, specialite;


-- ===== 6. Jointures : relier les tables =====
-- Le nom de la ville d'une école n'est pas dans la table ecoles : on n'y trouve que ville_id.
-- Une jointure (JOIN) relie deux tables en associant les lignes dont les clés correspondent,
-- ici ecoles.ville_id = villes.id.
--
-- On donne un alias court à chaque table (e pour ecoles, v pour villes) : on peut alors écrire
-- e.nom (le nom de l'école) ou v.nom (le nom de la ville) sans ambiguïté.

-- --- 6.1 · INNER JOIN : écoles et villes ---
-- INNER JOIN ne garde que les lignes qui ont une correspondance des deux côtés. La condition
-- de jointure s'écrit après ON.
SELECT e.nom AS ecole, v.nom AS ville
FROM ecoles AS e
INNER JOIN villes AS v ON v.id = e.ville_id
LIMIT 5;

-- --- 6.2 · Deux jointures : écoles, villes, pays ---
-- On enchaîne les jointures comme les maillons d'une chaîne : école → ville → pays. Puis on
-- compte les écoles de chaque pays : première brique du tableau de bord.
SELECT p.nom AS pays, COUNT(*) AS nb_ecoles
FROM ecoles AS e
INNER JOIN villes AS v ON v.id = e.ville_id
INNER JOIN pays   AS p ON p.id = v.pays_id
GROUP BY p.nom
ORDER BY p.nom;

-- --- 6.3 · LEFT JOIN : y a-t-il des villes sans école ? ---
-- LEFT JOIN garde toutes les lignes de la table de gauche (celle du FROM), même sans
-- correspondance ; les colonnes de la table de droite valent alors NULL. D'où une technique
-- classique pour trouver les « orphelins » : LEFT JOIN, puis WHERE ... IS NULL.
SELECT v.nom AS ville_sans_ecole
FROM villes AS v
LEFT JOIN ecoles AS e ON e.ville_id = v.id
WHERE e.id IS NULL;
-- Résultat vide : chacune des 12 villes a au moins une école. Un résultat vide est aussi une
-- information ! Cherchons d'autres absences de correspondance, du côté des classes.

-- --- 6.4 · Les classes d'une école et leurs effectifs ---
-- Prenons l'École Weber – Marseille (ecole_id = 5) : ses classes de 2025-2026 et le nombre
-- d'élèves inscrits dans chacune. COUNT(i.id) ne compte que les valeurs non NULL : une classe
-- sans aucune inscription affiche donc 0. Avec un INNER JOIN, ces classes auraient tout
-- simplement disparu du résultat, sans prévenir.
SELECT c.nom AS classe, COUNT(i.id) AS nb_inscrits
FROM classes AS c
LEFT JOIN inscriptions AS i ON i.classe_id = c.id
WHERE c.ecole_id = 5
  AND c.annee_scolaire_id = 7
GROUP BY c.nom
ORDER BY c.nom;

-- --- 6.5 · Combien de classes vides, et dans quelles écoles ? ---
-- On combine les deux jointures : INNER JOIN vers ecoles (chaque classe a une école) et LEFT
-- JOIN vers inscriptions avec i.id IS NULL pour ne garder que les classes sans aucun inscrit.
SELECT e.nom AS ecole, e.niveau_ecole, COUNT(*) AS classes_sans_eleve
FROM classes AS c
INNER JOIN ecoles AS e ON e.id = c.ecole_id
LEFT JOIN inscriptions AS i ON i.classe_id = c.id
WHERE c.annee_scolaire_id = 7
  AND i.id IS NULL
GROUP BY e.nom, e.niveau_ecole
ORDER BY classes_sans_eleve DESC, e.nom;
-- 💡 Constat à remonter à la direction : 56 classes ouvertes en 2025-2026 n'ont aucun élève
-- inscrit (11 + 11 + 9 + 9 + 8 + 8), toutes dans les 6 écoles primaires (qui n'accueillent que
-- 23 élèves à elles six). Classes fermées mais restées dans la base ? Inscriptions non
-- saisies ? Le SQL ne tranche pas, mais c'est exactement le genre d'anomalie qu'un état des
-- lieux doit signaler.

-- ✍️ Exercice 4 : Les enseignants par pays
-- Combien d'enseignants travaillent dans chaque pays ? Reliez enseignants → ecoles (par
-- ecole_id) → villes → pays, puis comptez par pays, du plus grand nombre au plus petit.

-- ✅ Solution
SELECT p.nom AS pays, COUNT(*) AS nb_enseignants
FROM enseignants AS en
INNER JOIN ecoles AS e ON e.id = en.ecole_id
INNER JOIN villes AS v ON v.id = e.ville_id
INNER JOIN pays   AS p ON p.id = v.pays_id
GROUP BY p.nom
ORDER BY nb_enseignants DESC;
-- 102 + 97 + 78 = 277 : on retrouve bien tous les enseignants de la table.


-- ===== 7. Travailler avec des dates =====
-- PostgreSQL sait calculer sur les dates. Les outils de base :
-- - CURRENT_DATE : la date du jour (le résultat dépend donc du jour où vous exécutez la
--   requête) ;
-- - EXTRACT(YEAR FROM une_date) : extrait l'année (ou MONTH pour le mois, DAY pour le jour) ;
-- - AGE(date_recente, date_ancienne) : la durée écoulée entre deux dates, en années, mois et
--   jours ;
-- - date_trunc('month', une_date) : ramène une date au 1er jour de son mois, idéal pour
--   compter « par mois » ;
-- - DATE '2025-09-01' : une date écrite en dur, au format année-mois-jour.

-- --- 7.1 · L'ancienneté des écoles ---
-- Pour chaque école : son année de création et son âge en années. EXTRACT(YEAR FROM AGE(...))
-- ne garde que le nombre d'années entières de la durée.
SELECT nom,
       date_creation,
       EXTRACT(YEAR FROM date_creation)                    AS annee_creation,
       EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_creation)) AS anciennete_ans
FROM ecoles
ORDER BY date_creation
LIMIT 5;

-- --- 7.2 · Les absences par mois en 2025-2026 ---
-- date_trunc('month', date_debut) donne le 1er jour du mois de chaque absence. On regroupe sur
-- ce mois en réutilisant le nom de la colonne calculée, mois, dans le GROUP BY (PostgreSQL
-- l'accepte). CAST(... AS date) convertit le résultat (une date avec heure) en simple date,
-- plus lisible. Le BETWEEN borne l'année scolaire (la table absences n'a pas de colonne
-- annee_scolaire_id).
SELECT CAST(date_trunc('month', date_debut) AS date) AS mois,
       COUNT(*) AS nb_absences
FROM absences
WHERE date_debut BETWEEN DATE '2025-09-01' AND DATE '2026-07-31'
GROUP BY mois
ORDER BY mois;
-- Janvier 2026 est le mois le plus chargé (137 absences), février le plus calme (88).

-- ✍️ Exercice 5 : Les enseignants les plus anciens
-- Pour préparer une remise de médailles, affichez le prénom, le nom, la spécialité, la date
-- d'embauche et l'ancienneté en années des 5 enseignants embauchés depuis le plus longtemps.

-- ✅ Solution
SELECT prenom, nom, specialite, date_embauche,
       EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_embauche)) AS anciennete_ans
FROM enseignants
ORDER BY date_embauche
LIMIT 5;


-- ===== 8. CASE WHEN : créer des catégories =====
-- CASE WHEN condition THEN valeur ... ELSE valeur END crée une colonne calculée selon des
-- conditions testées dans l'ordre : la première condition vraie l'emporte. Transformons les
-- moyennes du 1er trimestre 2025-2026 en mentions : 16 et plus « Très bien », 14 et plus
-- « Bien », 12 et plus « Assez bien », 10 et plus « Passable », sinon « Insuffisant ».

-- --- 8.1 · Une mention pour chaque bulletin ---
-- Grâce à l'ordre des tests, une moyenne de 15 n'est pas « Très bien » (15 < 16) mais s'arrête
-- à « Bien » (15 ≥ 14) : inutile d'écrire BETWEEN 14 AND 16.
SELECT eleve_id,
       moyenne_generale,
       CASE
           WHEN moyenne_generale >= 16 THEN 'Très bien'
           WHEN moyenne_generale >= 14 THEN 'Bien'
           WHEN moyenne_generale >= 12 THEN 'Assez bien'
           WHEN moyenne_generale >= 10 THEN 'Passable'
           ELSE 'Insuffisant'
       END AS mention
FROM bulletins
WHERE annee_scolaire_id = 7 AND trimestre = 1
ORDER BY eleve_id
LIMIT 10;

-- --- 8.2 · Combien d'élèves par mention ? ---
-- On regroupe sur la colonne calculée en réutilisant son alias mention dans le GROUP BY, comme
-- pour mois en 7.2.
SELECT CASE
           WHEN moyenne_generale >= 16 THEN 'Très bien'
           WHEN moyenne_generale >= 14 THEN 'Bien'
           WHEN moyenne_generale >= 12 THEN 'Assez bien'
           WHEN moyenne_generale >= 10 THEN 'Passable'
           ELSE 'Insuffisant'
       END AS mention,
       COUNT(*) AS nb_eleves
FROM bulletins
WHERE annee_scolaire_id = 7 AND trimestre = 1
GROUP BY mention
ORDER BY nb_eleves DESC;
-- 💡 Vérification : la table bulletins contient déjà une colonne appreciation, remplie
-- indépendamment de notre requête. Remplacez tout le CASE ... END AS mention par appreciation
-- (et GROUP BY mention par GROUP BY appreciation) : vous obtenez exactement les mêmes
-- effectifs (822, 567, 477, 247, 96). Recouper deux calculs indépendants est un excellent
-- réflexe.

-- ✍️ Exercice 6 : Petites, moyennes et grandes écoles
-- Classez les écoles selon leur capacité : petite (moins de 400 places), moyenne (de 400 à
-- 799), grande (800 et plus). Combien d'écoles compte chaque catégorie ?

-- ✅ Solution
SELECT CASE
           WHEN capacite_max < 400 THEN 'petite'
           WHEN capacite_max < 800 THEN 'moyenne'
           ELSE 'grande'
       END AS taille,
       COUNT(*) AS nb_ecoles
FROM ecoles
GROUP BY taille
ORDER BY nb_ecoles DESC;


-- ===== 9. Les vues : des requêtes enregistrées =====
-- Une vue est une requête enregistrée dans la base sous un nom. On l'interroge exactement
-- comme une table, mais elle est recalculée à chaque appel. Notre base en propose deux :
-- - v_classement_classe : le rang de chaque élève dans sa classe, par trimestre (à partir des
--   bulletins) ;
-- - v_moyennes_eleves : la moyenne de chaque élève dans chaque matière, calculée à partir du
--   million de notes.
--
-- ⚠️ Une vue peut cacher un calcul lourd : v_moyennes_eleves parcourt la table notes.
-- Filtrez-la toujours (sur un élève ou une classe) ; n'écrivez jamais SELECT * FROM
-- v_moyennes_eleves sans WHERE.

-- --- 9.1 · Le podium de la classe la plus chargée ---
-- La classe n°597, repérée en partie 5 avec ses 63 élèves, est la 4ème A de l'École Collet –
-- Porto-Novo. Qui sont ses 5 premiers au 1er trimestre ? La vue fait les jointures à notre
-- place : on se contente de filtrer.
SELECT rang, eleve_id, eleve_prenom, eleve_nom, moyenne_generale, appreciation
FROM v_classement_classe
WHERE classe_id = 597
  AND trimestre = 1
ORDER BY rang
LIMIT 5;

-- --- 9.2 · Les moyennes par matière d'une élève ---
-- L'élève classée 1re ci-dessus porte le numéro (eleve_id) 1264. Ses moyennes par matière sur
-- toute l'année 2025-2026, avec la vue v_moyennes_eleves filtrée sur cette seule élève :
-- PostgreSQL ne lit que ses notes, et la réponse arrive en moins d'une seconde au lieu d'un
-- calcul sur plus d'un million de notes.
SELECT matiere, coefficient_matiere, moyenne_matiere
FROM v_moyennes_eleves
WHERE eleve_id = 1264
  AND annee_scolaire = '2025-2026'
ORDER BY moyenne_matiere DESC;


-- ===== 10. Cas d'usage final : le tableau de bord 2025-2026 =====
-- Tout est prêt pour répondre à la direction. Le livrable : une ligne par pays avec le nombre
-- d'écoles, le nombre de classes ouvertes en 2025-2026, le nombre d'élèves inscrits en
-- 2025-2026 et la moyenne générale du 1er trimestre. On construit la requête en deux étapes.

-- --- 10.1 · Étape 1 : écoles et classes par pays ---
-- On descend la chaîne pays → villes → écoles → classes, en ne gardant que les classes de
-- 2025-2026. Après les jointures, une même école apparaît sur plusieurs lignes (une par
-- classe) : COUNT(DISTINCT e.id) compte chaque école une seule fois.
SELECT p.nom                AS pays,
       COUNT(DISTINCT e.id) AS nb_ecoles,
       COUNT(DISTINCT c.id) AS nb_classes
FROM pays AS p
INNER JOIN villes  AS v ON v.pays_id = p.id
INNER JOIN ecoles  AS e ON e.ville_id = v.id
INNER JOIN classes AS c ON c.ecole_id = e.id
WHERE c.annee_scolaire_id = 7
GROUP BY p.nom
ORDER BY p.nom;

-- --- 10.2 · Étape 2 : ajouter les élèves et la moyenne du 1er trimestre ---
-- On ajoute deux maillons avec LEFT JOIN :
-- - inscriptions, pour compter les élèves (COUNT(DISTINCT i.eleve_id)) ; le LEFT JOIN conserve
--   les 56 classes vides de la partie 6 dans le nombre de classes ;
-- - bulletins, pour la moyenne : pour chaque élève inscrit, on prend son bulletin de 2025-2026
--   au 1er trimestre.
--
-- Les conditions sur les bulletins sont placées dans le ON, pas dans le WHERE : dans le WHERE,
-- b.trimestre = 1 éliminerait les lignes des classes vides (où b.trimestre vaut NULL) et
-- fausserait le nombre de classes.
SELECT p.nom                             AS pays,
       COUNT(DISTINCT e.id)              AS nb_ecoles,
       COUNT(DISTINCT c.id)              AS nb_classes,
       COUNT(DISTINCT i.eleve_id)        AS nb_eleves_inscrits,
       ROUND(AVG(b.moyenne_generale), 2) AS moyenne_t1
FROM pays AS p
INNER JOIN villes  AS v ON v.pays_id = p.id
INNER JOIN ecoles  AS e ON e.ville_id = v.id
INNER JOIN classes AS c ON c.ecole_id = e.id
LEFT JOIN inscriptions AS i ON i.classe_id = c.id
LEFT JOIN bulletins    AS b ON b.eleve_id = i.eleve_id
                           AND b.annee_scolaire_id = 7
                           AND b.trimestre = 1
WHERE c.annee_scolaire_id = 7
GROUP BY p.nom
ORDER BY nb_eleves_inscrits DESC;
-- Lecture du tableau de bord (chiffres obtenus lors de la préparation du TP) :
-- - 8 écoles dans chaque pays ; 187 classes ouvertes au total (66 au Bénin, 64 au Sénégal, 57
--   en France), dont 56 sans élève (partie 6) ;
-- - 2 209 élèves inscrits : 827 au Bénin, 726 en France, 656 au Sénégal ;
-- - des moyennes du 1er trimestre très proches, autour de 11/20 : de 10,83 en France à 11,00
--   au Bénin.
--
-- 💡 Recouper avant de livrer : 827 + 726 + 656 = 2 209, exactement le nombre de bulletins du
-- 1er trimestre trouvé en partie 5, et la moyenne globale de 10,92 se situe bien entre les
-- moyennes des trois pays. Deux chemins différents, le même résultat : on peut livrer. Dans
-- DataGrip, exportez ce résultat en CSV (fiche de connexion, étape 8) pour l'envoyer à la
-- direction.


-- ===== 11. Bonus : WITH, RANK() et EXPLAIN =====
-- Trois outils pour aller plus loin, si vous avez terminé en avance.

-- --- 11.1 · WITH : nommer une étape intermédiaire (CTE) ---
-- Une CTE (Common Table Expression) est une sous-requête à laquelle on donne un nom avec WITH
-- nom AS (...), puis qu'on utilise comme une table. La requête se lit alors de haut en bas,
-- étape par étape. Question : quelles classes de 2025-2026 ont plus d'élèves inscrits que leur
-- effectif maximal prévu (effectif_max) ?
WITH inscrits_par_classe AS (
    SELECT classe_id, COUNT(*) AS nb_inscrits
    FROM inscriptions
    WHERE annee_scolaire_id = 7
    GROUP BY classe_id
)
SELECT e.nom AS ecole, c.nom AS classe, c.effectif_max, ipc.nb_inscrits
FROM inscrits_par_classe AS ipc
INNER JOIN classes AS c ON c.id = ipc.classe_id
INNER JOIN ecoles  AS e ON e.id = c.ecole_id
WHERE ipc.nb_inscrits > c.effectif_max
ORDER BY ipc.nb_inscrits DESC, c.id
LIMIT 10;
-- Deuxième constat pour la direction : 12 classes sont en sureffectif (retirez le LIMIT pour
-- les voir toutes). La 4ème A de l'École Collet – Porto-Novo accueille 63 élèves pour 33
-- places prévues.

-- --- 11.2 · RANK() : une fonction de fenêtre ---
-- Une fonction de fenêtre calcule une valeur pour chaque ligne en regardant les autres lignes,
-- sans les regrouper. RANK() OVER (ORDER BY moyenne_t1 DESC) donne le rang de chaque école :
-- le rang 1 revient à la meilleure moyenne du 1er trimestre. Avec PARTITION BY, on obtiendrait
-- un classement séparé dans chaque groupe (exemple dans « Pour aller plus loin »).
WITH moyennes_ecoles AS (
    SELECT e.nom AS ecole,
           COUNT(*) AS nb_eleves,
           ROUND(AVG(b.moyenne_generale), 2) AS moyenne_t1
    FROM bulletins AS b
    INNER JOIN classes AS c ON c.id = b.classe_id
    INNER JOIN ecoles  AS e ON e.id = c.ecole_id
    WHERE b.annee_scolaire_id = 7 AND b.trimestre = 1
    GROUP BY e.nom
)
SELECT RANK() OVER (ORDER BY moyenne_t1 DESC) AS rang, ecole, nb_eleves, moyenne_t1
FROM moyennes_ecoles
ORDER BY rang, ecole
LIMIT 5;
-- ⚠️ Regardez nb_eleves : les trois premières écoles n'ont que 2 à 6 élèves notés (les écoles
-- primaires, presque vides). Une moyenne sur 4 élèves n'est pas comparable à une moyenne
-- sur 150. Ajoutez HAVING COUNT(*) >= 30 dans la CTE (après le GROUP BY) pour ne classer que
-- les écoles suffisamment grandes.

-- --- 11.3 · EXPLAIN : le plan d'exécution ---
-- EXPLAIN affiche le plan d'exécution choisi par PostgreSQL, sans exécuter la requête. Ici, on
-- cherche les notes d'un élève : la colonne eleve_id possède un index (comme l'index à la fin
-- d'un livre) et PostgreSQL saute directement aux bonnes lignes (Index Scan ou Index Only
-- Scan).
EXPLAIN
SELECT COUNT(*) FROM notes WHERE eleve_id = 1264;

-- --- 11.4 · EXPLAIN sans index : lecture complète ---
-- Même question sur les notes égales à 20 : il n'y a pas d'index sur la colonne note,
-- PostgreSQL doit lire toute la table (Seq Scan, lecture séquentielle, ici répartie sur
-- plusieurs processus : Parallel).
EXPLAIN
SELECT COUNT(*) FROM notes WHERE note = 20;
-- Comparez les valeurs cost (une estimation de l'effort, en unités arbitraires) des deux
-- plans : quelques unités avec l'index, plusieurs milliers sans. C'est pourquoi on filtre de
-- préférence sur des colonnes indexées, surtout sur une base partagée.


-- ===== Fin du TP : fermer la connexion =====
-- Que vous ayez fait le bonus ou non, déconnectez-vous de la base (bouton carré rouge
-- « Disconnect » de la barre du Database Explorer) pour libérer votre connexion au pooler
-- partagé.


-- ===== Récapitulatif =====
-- Ce que vous avez fait
-- - exploré une base inconnue : information_schema, COUNT(*), clés primaires et étrangères ;
-- - lu des données avec SELECT, WHERE, ORDER BY, DISTINCT, LIMIT ;
-- - résumé avec COUNT, AVG, MIN, MAX, GROUP BY, HAVING ;
-- - relié jusqu'à six tables avec INNER JOIN et LEFT JOIN, calculé sur des dates, créé des
--   catégories avec CASE WHEN, interrogé des vues ;
-- - livré le tableau de bord 2025-2026 par pays, et repéré deux anomalies à signaler (56
--   classes sans élève, 12 classes en sureffectif).
--
-- Les réflexes à retenir
-- - compter (COUNT(*)) avant de récupérer, et toujours un LIMIT ou un filtre sur une base
--   partagée ;
-- - ne sélectionner que les colonnes utiles : c'est plus rapide, et c'est la minimisation du
--   RGPD ;
-- - INNER JOIN fait disparaître les lignes sans correspondance ; LEFT JOIN + IS NULL trouve
--   les orphelins ;
-- - WHERE filtre les lignes, HAVING filtre les groupes ; NULL se teste avec IS NULL ;
-- - recouper un chiffre par deux chemins différents avant de le livrer ;
-- - ici, lecture seule : uniquement des SELECT.


-- ===== Pour aller plus loin =====
-- - Interroger la même base depuis Python (psycopg, pandas) pour enchaîner sur des traitements
--   et des fichiers : c'est l'objet du notebook 02_postgres_python.ipynb.
-- - Recalculer le rang des élèves dans chaque classe avec RANK() OVER (PARTITION BY classe_id
--   ORDER BY moyenne_generale DESC) et le comparer à la colonne rang de la table bulletins.
-- - Dans DataGrip : afficher le diagramme du schéma public, puis essayer Explain Plan (clic
--   droit sur une requête) pour voir le plan d'exécution sous forme graphique.
-- - Documentation PostgreSQL en français, chapitre « Le langage SQL » :
--   https://docs.postgresql.fr/
