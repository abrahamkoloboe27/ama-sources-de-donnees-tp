# Plan du TP « Sources de données » — séance de 3 h

Fiche de déroulé pour l'enseignant (et pour les étudiants qui veulent savoir où ils vont).
Le cours de 3 h a posé les notions ; le TP les met en pratique sur **cinq sources réelles** : se connecter, récupérer, enregistrer proprement.

## Objectifs : à la fin du TP, l'étudiant sait…

1. se connecter à une base **PostgreSQL** depuis un client SQL (DataGrip) et depuis Python, sans exposer ses identifiants ;
2. écrire des requêtes SQL de base (filtrer, agréger, joindre) et faire travailler la base plutôt que tout rapatrier ;
3. interroger une base **MongoDB** (filtre, projection, agrégation) et ramener des documents JSON dans pandas ;
4. télécharger des **fichiers open data** de façon traçable et relançable (empreinte, manifeste, idempotence), et les interroger en SQL avec DuckDB ;
5. consommer une **API REST** : codes HTTP, erreurs, pagination, politesse (pauses, `User-Agent`, 429) ;
6. **scraper** un site poliment (robots.txt, cache, pauses) quand il n'y a ni API ni fichier ;
7. croiser plusieurs sources avec une **clé de jointure** fiable et livrer un résultat contrôlé (Parquet, DuckDB).

---

## Avant la séance

### Côté enseignant (J-7 à J-1)

| ✔ | Action | Pourquoi |
|---|---|---|
| ☐ | **Distribuer le `.env`** par un canal privé (ENT, Teams, e-mail), jamais dans le dépôt | Le dépôt est public ; seul `.env.example` y figure |
| ☐ | **MongoDB Atlas → Network Access** : autoriser l'IP publique de l'école (ou `0.0.0.0/0` le temps du TP, à retirer ensuite) | Sinon, tous les étudiants obtiennent `ServerSelectionTimeoutError` |
| ☐ | **Créer des comptes en lecture seule** (recommandé, voir ci-dessous) | Les comptes actuels (`postgres`, `reporting`) ont les droits d'écriture |
| ☐ | Tester soi-même la **connexion DataGrip** avec [la fiche](connexion_datagrip.md) | Les menus de la fiche n'ont pas été vérifiés dans un vrai DataGrip |
| ☐ | Vérifier que le réseau de la salle laisse passer les ports **6543** (PostgreSQL) et **27017** (Atlas), et le domaine `extensions.duckdb.org` | Certains pare-feu n'ouvrent que les ports 80 et 443 ; DuckDB télécharge son extension `httpfs` (notebooks 00 et 04) |
| ☐ | Si la séance a lieu bien après octobre 2026 : relancer les notebooks et mettre à jour les mois NYC TLC codés en dur (notebook 04) | Plusieurs sorties dépendent de la date (météo, mois publiés, fichiers datés) |
| ☐ | Préparer le **QCM** de 15 questions (hors dépôt) | Le dépôt étant public, le QCM n'y est pas |

#### Comptes en lecture seule (recommandé)

**PostgreSQL (Supabase)** : dans l'éditeur SQL de Supabase, en tant que `postgres`.

```sql
CREATE ROLE tp_lecture LOGIN PASSWORD 'un-mot-de-passe-solide';
GRANT USAGE ON SCHEMA public TO tp_lecture;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO tp_lecture;
-- Garde-fou : une requête oubliée sans filtre est coupée au bout de 30 s
ALTER ROLE tp_lecture SET statement_timeout = '30s';
```

À travers le pooler, l'utilisateur s'écrit `tp_lecture.<identifiant-projet>` (même format que `postgres.<identifiant-projet>`). Mettez-le dans le `.env` distribué, après l'avoir testé avec le notebook 00.

**MongoDB Atlas** : *Database Access → Add New Database User*, rôle intégré **« Only read any database »** (ou un rôle `read` limité à `ride_share_v1`).

### Côté étudiants (la veille)

1. Cloner le dépôt et installer les dépendances (`uv sync` ou `pip install -r requirements.txt`), voir le [README](../README.md).
2. Créer le fichier `.env` à partir de `.env.example`, avec les valeurs reçues.
3. Exécuter le **notebook 00** et garder sa check-list (capture d'écran) : tout doit être **OK**.
4. Installer **DataGrip** (licence éducative JetBrains gratuite) et créer la connexion avec [la fiche](connexion_datagrip.md).

---

## Déroulé de la séance

| Horaire | Bloc | Support | L'enseignant | Les étudiants |
|---|---|---|---|---|
| 0:00 – 0:15 | **QCM noté** | — | Distribue et ramasse le QCM | Répondent aux 15 questions sur le cours |
| 0:15 – 0:25 | **Check-in** | notebook 00 | Fait le tour des check-lists et règle les ÉCHEC (section 9 du notebook) | Montrent leur check-list ; aident leur voisin |
| 0:25 – 1:05 | **A · SQL dans DataGrip** | `sql/01_postgres_datagrip.sql` (ou notebook 01) | Démontre en direct les parties 0 à 6 (≈ 20 min) : connexion, `information_schema`, `SELECT`, `WHERE`, `GROUP BY`, jointures | Enchaînent les parties 7 à 10 (dates, `CASE`, vues, tableau de bord) et les exercices 1 à 4 ; partie 11 en bonus |
| 1:05 – 1:30 | **B · PostgreSQL depuis Python** | notebook 02 | Démontre les sections 6 (gros volumes) et 7 (incrémental) au vidéoprojecteur | Font les sections 1 à 5 : `psycopg`, requête paramétrée, `read_sql`, export des bulletins en CSV et en Parquet |
| 1:30 – 1:40 | Pause | | | |
| 1:40 – 2:15 | **C · MongoDB** | notebook 03 | Commente la section 8 (qualité : devises, villes orphelines) avec la classe | Font les sections 1 à 7 : connexion, `find`, `count_documents`, pandas, `$lookup`, pipeline d'agrégation |
| 2:15 – 2:50 | **D · Atelier au choix**, en binôme | notebook 04, 05 ou 06 | Répartit la salle en trois tiers (un atelier par tiers), circule | **04** fichiers NYC Taxi · **05** API Banque mondiale et Open-Meteo · **06** scraping de books.toscrape.com |
| 2:50 – 3:00 | **Restitution** | | Synthèse au tableau | Chaque binôme donne **un chiffre** obtenu et **un réflexe** retenu |
| **Après** | Autonomie | notebooks 04 à 07 | | Les deux ateliers non choisis, puis le notebook 07 (intégration), exercices restants |

### Pourquoi ce découpage

- **Les bases (A, B, C) se font en salle**, car c'est là que les débutants bloquent (connexion, identifiants, SQL) et qu'on a besoin de l'enseignant.
- **Les sources web (D) se font en ateliers** : elles sont plus autonomes, et répartir la salle en trois groupes étale la charge réseau (téléchargements, API, site scrapé).
- **Certaines sections lourdes sont démontrées, pas exécutées par tous** : notebook 02 §6-7 et notebook 03 §8. Trente parcours complets simultanés de la table `notes` (1,2 M lignes, sans index sur `date_saisie`) chargeraient inutilement la base partagée.

### Si vous avez moins de temps

- Sans QCM : +15 min pour l'atelier D ou pour une démonstration du notebook 07 en fin de séance.
- Si la partie A déborde : arrêtez-vous à la partie 10 (tableau de bord), la partie 11 est un bonus.
- Si le réseau est mauvais : l'atelier **06** fonctionne avec un cache (on peut relancer sans retélécharger), et dans le **04**, les taxis verts ne pèsent que ≈ 1 Mo par mois.

---

## Messages clés à faire passer, bloc par bloc

| Bloc | Message clé | Lien avec le cours |
|---|---|---|
| Check-in (00) | Les secrets vivent dans `.env`, jamais dans le code ; une URI se lit comme une adresse | Partie 4, éthique |
| A (01) | SQL est déclaratif : on dit **quoi**, la base trouve **comment** ; le schéma impose les règles (clés, `CHECK`) | Slides 7, 9, 16 |
| B (02) | Faire travailler la base (agréger côté serveur) ; requêtes paramétrées ; extraction **complète vs incrémentale** | Slides 30, 35 |
| C (03) | Un document = une commande avec ses lignes ; « schemaless » ne veut pas dire sans schéma ; la **véracité** se vérifie | Slides 9, 10, 19 |
| D · 04 | Les 4 réflexes du téléchargement (dater, empreinte, garder le brut, noter la source) ; **Parquet** colonnaire, lisible à distance | Slides 29, 32, 39 |
| D · 05 | Codes HTTP, `raise_for_status`, pagination, 429 ; un « 200 » peut cacher une erreur | Slides 40, 41, 42 |
| D · 06 | Scraping en **dernier recours**, poli et fragile ; `robots.txt`, cache, pauses | Slides 38, 43, 45 |
| 07 | La **clé de jointure** (code ISO) plutôt que le nom ; ELT en couches ; chargement **idempotent** ; contrôles qualité | Slides 32, 34 |

## Correspondance cours ↔ notebooks

| Notion du cours | Slide | Où la pratiquer |
|---|---|---|
| SQL : DDL, DML, DQL | 7 | 01 |
| Une requête, trois langages (SQL, MQL) | 9 | 01, 03 |
| Les 5 V : véracité | 10 | 03 (§8), 07 (§7) |
| Relationnel : clés, contraintes, index | 16, annexe A1 | 01, `docs/schema_postgres.sql` |
| Document : le piège du « schemaless » | 19 | 03, `docs/schema_mongodb.md` |
| Formats : CSV contre Parquet (démo DuckDB) | 29 | 02 (§5), 04 (§8) |
| OLTP / OLAP : ne pas analyser sur la prod | 30 | 02 (§6), 04 (DuckDB) |
| Data lake bronze / silver / gold | 32 | 04, 05 (§8), 07 |
| Pipeline ELT, qualité | 34 | 07 |
| Extraction complète ou incrémentale, CDC | 35 | 02 (§7), 03 (§9) |
| Panorama des sources externes, règle d'or | 38 | 06 (§2) |
| Téléchargement et open data : 4 réflexes | 39 | 04 |
| API REST : verbes, codes, anatomie | 40, 41 | 05 |
| Authentification, pagination, 429 | 42 | 05 (§6, §7, §11) |
| Web scraping | 43 | 06 |
| Stratégie et éthique de la collecte (RGPD, minimisation) | 45 | 02 (§5), 06 (§2) |

---

## Points de vigilance le jour J

| Sujet | Ce qui peut arriver | Parade |
|---|---|---|
| **Pooler PostgreSQL** | Le mode session (port 5432) refuse au-delà de **15 clients**. Le mode transaction (6543) en accepte bien plus, mais avec peu de connexions serveur derrière | Port 6543 partout (déjà dans le `.env`) ; démontrer 02 §6-7 plutôt que les faire exécuter par tous |
| **Requêtes préparées** | Avec le port 6543 : `prepared statement "_pg3_0" already exists` | Déjà géré : `prepare_threshold=None` en Python, `prepareThreshold=0` dans DataGrip |
| **Charge MongoDB** | Seul `_id` est indexé : le notebook 03 parcourt `trips` (335 000 documents) une dizaine de fois. Sur un cluster Atlas gratuit (M0), il peut y avoir du bridage | Décaler les lancements ; faire commenter la section 8 au tableau |
| **Réseau** | Atelier 04 : ≈ 25 Mo par étudiant (dont l'extension DuckDB `httpfs`, 7 à 10 Mo). Atelier 06 : ≈ 53 requêtes par étudiant. L'API Banque mondiale répond parfois en plus de 60 s | Répartir les ateliers en tiers ; partage de connexion en secours ; relancer la cellule en cas de délai dépassé |
| **Sorties datées** | Météo, mois NYC publiés, fichiers datés : les chiffres des étudiants diffèrent des sorties du dépôt | C'est normal (et pédagogique : la donnée vit) ; le dire en début de séance |
| **Données personnelles** | Les sorties contiennent des noms et e-mails **fictifs** (Faker) | Rappeler la minimisation : on n'exporte jamais e-mails et téléphones |

## Évaluation (proposition)

Le cours annonce un TD/TP noté : QCM + séquences. Les solutions des exercices sont dans le dépôt : on évalue donc des **variantes** à rendre, plus la capacité à expliquer.

| Élément | Points | Livrable possible |
|---|---:|---|
| QCM (15 questions) | 20 | — |
| A · SQL | 20 | Le tableau de bord de la partie 10 pour l'année **2024-2025**, exporté en CSV depuis DataGrip |
| B · PostgreSQL + Python | 15 | Le fichier des bulletins du **2e trimestre**, en Parquet, sans donnée personnelle |
| C · MongoDB | 20 | Les trois chiffres du directeur pour **octobre 2025** |
| D · Atelier | 15 | L'atelier choisi rejoué avec un autre paramètre : un autre mois de taxis, d'autres pays ou un autre indicateur, une autre catégorie de livres |
| Explication | 10 | Pour chaque livrable, deux phrases : « d'où vient la donnée, comment je l'ai vérifiée » |
| **Bonus** | +5 | Montrer qu'un chargement est **idempotent** : relancer ne crée pas de doublon |
