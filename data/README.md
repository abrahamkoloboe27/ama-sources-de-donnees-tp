# Dossier `data/`

Ce dossier est **vide dans le dépôt** : il se remplit quand vous exécutez les notebooks.
Son contenu est ignoré par Git (voir `.gitignore`), car on ne versionne ni les données brutes ni les gros fichiers.

| Sous-dossier | Contenu | Produit par |
|---|---|---|
| `raw/postgres/` | extractions brutes et fichier d'état de l'extraction incrémentale | notebook 02 |
| `raw/mongodb/` | extractions brutes MongoDB | notebook 03 |
| `raw/nyc_taxi/` | fichiers Parquet/CSV des taxis de New York + `manifest.json` | notebook 04 |
| `raw/api/` | réponses JSON brutes des API (Banque mondiale, Open-Meteo) | notebook 05 |
| `raw/scraping/` | pages HTML mises en cache | notebook 06 |
| `processed/` | fichiers propres (CSV, Parquet) prêts à l'analyse | notebooks 02 à 07 |
| `tp_integration.duckdb` | petite base analytique locale | notebook 07 |

Vous pouvez supprimer ce dossier à tout moment : relancer les notebooks le recrée.
