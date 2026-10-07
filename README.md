# TP · Sources de données — AMA

Travaux pratiques du module **« Sources de données »** (UE Ingénierie des données, AMA · cours 3 h + TD/TP 3 h).

**Objectif :** apprendre à **se connecter** à des sources très différentes et à en **récupérer la donnée** proprement : une base relationnelle (PostgreSQL), une base document (MongoDB), des fichiers open data, des API REST et un site web.

Chaque notebook part d'un **cas d'usage concret** (une demande réaliste), avance pas à pas avec une explication avant chaque cellule de code, puis propose des **exercices corrigés**. Aucune expérience des bases de données n'est nécessaire.

---

## Les sources de données du TP

| Source | Type | Comment on la récupère | Notebook |
|---|---|---|---|
| **PostgreSQL** « gestion scolaire » (Supabase) : 24 écoles en France, au Bénin et au Sénégal | base relationnelle (SQL) | DataGrip, puis Python (`psycopg`, `pandas` + SQLAlchemy) | 01, 02 |
| **MongoDB** « ride share » (Atlas) : VTC, livraison et location dans 19 pays africains | base document (NoSQL) | Python (`pymongo`) : `find`, agrégations | 03 |
| **Taxis de New York** (NYC TLC) : un fichier Parquet par mois | fichiers open data | `requests` (téléchargement), DuckDB (SQL sur fichiers) | 04 |
| **Banque mondiale** et **Open-Meteo** | API REST (JSON) | `requests` : paramètres, erreurs, pagination | 05 |
| **books.toscrape.com** | site web | `requests` + BeautifulSoup (scraping poli) | 06 |
| Toutes à la fois | intégration | pipeline ELT vers DuckDB et Parquet | 07 |

## Le parcours

| # | Notebook | Cas d'usage | Durée guidée (+ exercices) |
|---|---|---|---|
| 00 | [Vérifier son poste](notebooks/00_verifier_son_poste.ipynb) | Prouver avant la séance que son poste atteint les 5 sources, avec une check-list OK / ÉCHEC | 10 min (+ 5) |
| 01 | [PostgreSQL en SQL pur](notebooks/01_postgres_sql.ipynb) · [script DataGrip](sql/01_postgres_datagrip.sql) | État des lieux 2025-2026 d'un réseau de 24 écoles, du premier `SELECT` au tableau de bord par pays | 35 min (+ 15) |
| 02 | [PostgreSQL depuis Python](notebooks/02_postgres_python.ipynb) | Fichier des bulletins du 1er trimestre (CSV et Parquet) et export incrémental des nouvelles notes | 20 min (+ 15) |
| 03 | [MongoDB depuis Python](notebooks/03_mongodb_python.ipynb) | Chiffres du comité mensuel d'une application de VTC : courses par mois, chiffre d'affaires par devise, notes des chauffeurs | 30 min (+ 15) |
| 04 | [Fichiers open data : taxis de New York](notebooks/04_fichiers_nyc_taxi.ipynb) | Mini data lake de 6 mois de taxis verts, puis comparaison avec les taxis jaunes lus à distance | 25 min (+ 15) |
| 05 | [API REST : erreurs et pagination](notebooks/05_api_rest_pagination.ipynb) | Population et PIB par habitant des pays de l'UEMOA (2000-2024), météo de la semaine dans 5 villes | 25 min (+ 15) |
| 06 | [Web scraping poli](notebooks/06_scraping_books.ipynb) | Veille des prix d'un concurrent : catalogue complet de 1 000 livres sur 50 pages | 20 min (+ 15) |
| 07 | [Intégration multi-sources](notebooks/07_integration_multi_sources.ipynb) | Un tableau par pays qui croise MongoDB, PostgreSQL et la Banque mondiale (courses pour 100 000 habitants) | 15 min (+ 15) |

Le parcours complet dépasse les 3 heures de la séance : c'est voulu. Le **[plan de la séance](docs/plan_tp.md)** indique ce qui se fait en salle, en ateliers au choix et en autonomie.

### Déroulé de la séance de 3 h (résumé)

| Horaire | Bloc | Support |
|---|---|---|
| **Avant** | Installer, recevoir le `.env`, faire la check-list | notebook 00 |
| 0:00 – 0:15 | QCM noté sur le cours | — |
| 0:15 – 0:25 | Tour de salle : check-lists, dépannage | notebook 00 |
| 0:25 – 1:05 | **A · SQL dans DataGrip** | script `sql/01_…` (ou notebook 01) |
| 1:05 – 1:30 | **B · PostgreSQL depuis Python** | notebook 02 |
| 1:30 – 1:40 | Pause | |
| 1:40 – 2:15 | **C · MongoDB** | notebook 03 |
| 2:15 – 2:50 | **D · Atelier au choix** (en binôme) : fichiers, API ou scraping | notebook 04, 05 ou 06 |
| 2:50 – 3:00 | Restitution : un résultat et un réflexe par binôme | |
| **Après** | Les deux ateliers non choisis, puis l'intégration | notebooks 04 à 07 |

---

## Installation

### 1. Récupérer le dépôt

```bash
git clone https://github.com/abrahamkoloboe27/ama-sources-de-donnees-tp.git
cd ama-sources-de-donnees-tp
```

### 2. Installer les dépendances (Python ≥ 3.10)

Avec **uv** (recommandé) :

```bash
uv sync
```

Ou avec **pip**, dans un environnement virtuel :

```bash
python -m venv .venv
source .venv/bin/activate        # Windows : .venv\Scripts\activate
pip install -r requirements.txt
```

### 3. Créer votre fichier `.env`

Les identifiants des bases ne sont **jamais** écrits dans le code ni publiés sur GitHub. Ils vivent dans un fichier `.env`, à la racine du dépôt, que Git ignore.

```bash
cp .env.example .env             # Windows : copy .env.example .env
```

Ouvrez ensuite `.env` et remplacez les valeurs entre `< >` par celles données par l'enseignant.

### 4. Lancer Jupyter

```bash
uv run jupyter lab               # ou simplement : jupyter lab (environnement pip activé)
```

Ouvrez `notebooks/00_verifier_son_poste.ipynb` et exécutez-le : si toute la check-list est **OK**, vous êtes prêt. VS Code (extension Jupyter) fonctionne aussi : choisissez le noyau `.venv` du projet.

### 5. DataGrip (pour la partie SQL)

DataGrip est gratuit pour les étudiants (licence éducative JetBrains). La fiche **[docs/connexion_datagrip.md](docs/connexion_datagrip.md)** explique la connexion pas à pas. Deux réglages sont indispensables : le **port 6543** et `prepareThreshold = 0`.

---

## Structure du dépôt

```
├── notebooks/                    # les 8 notebooks du TP (00 à 07)
├── sql/
│   └── 01_postgres_datagrip.sql  # le notebook 01 sous forme de script, pour DataGrip
├── docs/
│   ├── plan_tp.md                # plan détaillé de la séance + fiche enseignant
│   ├── connexion_datagrip.md     # se connecter à PostgreSQL (et MongoDB) dans DataGrip
│   ├── schema_postgres.sql       # schéma commenté de la base « gestion scolaire » (à lire)
│   └── schema_mongodb.md         # collections, champs et pièges de la base « ride share »
├── data/                         # vide dans le dépôt : se remplit à l'exécution (ignoré par Git)
├── .env.example                  # modèle du fichier .env (à copier)
├── pyproject.toml / uv.lock      # dépendances (uv)
└── requirements.txt              # dépendances (pip)
```

## Les règles du TP

- **Lecture seule.** Les bases sont partagées par toute la promotion : uniquement des `SELECT` (PostgreSQL) et des `find` ou `aggregate` (MongoDB). Jamais d'`INSERT`, `UPDATE`, `DELETE`, `DROP`…
- **Requêtes légères.** Toujours un filtre, une projection ou un `LIMIT`. La table `notes` contient plus d'un million de lignes, la collection `trips` plus de 330 000 documents.
- **Secrets hors du code.** Le `.env` ne se committe jamais. N'affichez jamais un mot de passe dans une sortie de cellule.
- **Collecte responsable.** Ne prenez que les données utiles (minimisation), notez la source, la licence et la date, et soyez poli avec les serveurs : `User-Agent`, pauses, cache.

## Ça ne marche pas ?

La section 9 du [notebook 00](notebooks/00_verifier_son_poste.ipynb) liste les erreurs fréquentes et leurs solutions. Les plus courantes :

| Symptôme | Solution |
|---|---|
| `password authentication failed` / `Tenant or user not found` | Revérifier `PG_USER` (de la forme `postgres.<identifiant>`) et `PG_PASSWORD` dans `.env` |
| `prepared statement "_pg3_0" already exists` | Ajouter `prepare_threshold=None` à la connexion psycopg (déjà fait dans les notebooks) |
| `max clients reached in session mode` | Utiliser le port **6543** et non 5432 |
| Connexion impossible à `db.<projet>.supabase.co` | Cet hôte n'est joignable qu'en IPv6 : utiliser l'hôte du **pooler** donné dans `.env` |
| MongoDB : `ServerSelectionTimeoutError` | Réseau filtré ou adresse IP non autorisée sur Atlas : prévenir l'enseignant |

---

## Les données : sources et licences

- **PostgreSQL « gestion scolaire » et MongoDB « ride share »** : données **synthétiques** (générées avec Faker) créées pour l'enseignement. Les noms, e-mails et téléphones sont fictifs, mais on les traite comme des données personnelles.
- **NYC Taxi & Limousine Commission** : [TLC Trip Record Data](https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page), publiées en open data par la ville de New York.
- **Banque mondiale** : [API des indicateurs](https://datahelpdesk.worldbank.org/knowledgebase/articles/889392), données sous licence CC BY 4.0.
- **Open-Meteo** : [API météo](https://open-meteo.com/), gratuite pour un usage non commercial, données sous licence CC BY 4.0.
- **books.toscrape.com** : site « bac à sable » conçu pour s'entraîner au web scraping.

Le notebook 04 s'inspire du mini-pipeline taxis du dépôt [advanced-python-atut](https://github.com/abrahamkoloboe27/advanced-python-atut).

---

*Abraham Koloboe — Cloud Data Engineer · AMA, UE Ingénierie des données.*
