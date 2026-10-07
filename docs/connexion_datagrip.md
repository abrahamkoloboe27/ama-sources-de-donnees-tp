# Se connecter à la base PostgreSQL avec DataGrip

Cette fiche vous guide pas à pas pour interroger la base « gestion scolaire » du TP dans **DataGrip**, puis exécuter le script `sql/01_postgres_datagrip.sql` requête par requête. Comptez 10 minutes la première fois.

> 💡 **DataGrip** est un *client SQL* de JetBrains : un logiciel qui se connecte à une base de données, affiche ses tables et exécute vos requêtes. Il est gratuit pour les étudiants (licence éducative JetBrains). Il remplace ici le notebook `notebooks/01_postgres_sql.ipynb`, qui contient exactement les mêmes requêtes.

> ⚠️ **Sécurité** : les valeurs de connexion (hôte, utilisateur, mot de passe) vous sont **données par l'enseignant**. Ce sont les mêmes que dans votre fichier `.env`. Ne les écrivez jamais dans un fichier versionné (fiche, script SQL, notebook) et ne les publiez pas sur GitHub.

## Les valeurs à saisir

| Champ DataGrip | Valeur | Équivalent dans `.env` |
|---|---|---|
| Host | l'hôte du *pooler* Supabase (de la forme `aws-…-<région>.pooler.supabase.com`), fourni par l'enseignant | `PG_HOST` |
| Port | `6543` | `PG_PORT` |
| Authentication | `User & Password` | — |
| User | fourni par l'enseignant (de la forme `postgres.<identifiant-projet>`) | `PG_USER` |
| Password | fourni par l'enseignant | `PG_PASSWORD` |
| Database | `postgres` | `PG_DATABASE` |

Pourquoi ce port et cet hôte ? La base est hébergée chez Supabase. On passe par un **pooler** : un intermédiaire qui partage un petit nombre de connexions entre tous les étudiants. Le port **6543** correspond à son mode « transaction », prévu pour de nombreux clients simultanés (le port 5432, mode « session », est limité à 15 clients).

## 1. Créer la Data Source PostgreSQL

1. Ouvrez DataGrip. À gauche, la fenêtre **Database Explorer** (menu *View → Tool Windows → Database Explorer* si elle est fermée).
2. Cliquez sur **`+`** → **Data Source** → **PostgreSQL**.
3. Dans **Name**, donnez un nom parlant, par exemple `Gestion scolaire (TP)`.
4. Remplissez **Host**, **Port**, **User**, **Password** et **Database** avec les valeurs du tableau ci-dessus.
5. **Save** (mémorisation du mot de passe) : sur un ordinateur partagé, choisissez `Until restart` ou `Never` plutôt que `Forever`.

> 💡 Le champ **URL** (`jdbc:postgresql://…`) se remplit tout seul : c'est l'adresse de la base, au format attendu par le driver Java.

## 2. Télécharger le driver

Un **driver** (pilote) est la bibliothèque qui « parle » le protocole réseau de PostgreSQL. Dans le notebook, c'est `psycopg` ; dans DataGrip, c'est un driver **JDBC** (Java).

- Si un lien **Download missing driver files** apparaît en bas du formulaire, cliquez dessus et attendez la fin du téléchargement.

## 3. Onglet Advanced : `prepareThreshold = 0` (indispensable)

1. Ouvrez l'onglet **Advanced** de la fenêtre de connexion.
2. Dans la liste des propriétés du driver, trouvez **`prepareThreshold`** (tapez son nom pour filtrer la liste) et mettez la valeur **`0`**.
3. Dans la même liste, réglez **`sslmode`** sur **`require`** : la connexion sera chiffrée. Vous pouvez aussi passer par l'onglet **SSH/SSL** : cochez **Use SSL** et choisissez le mode **Require**.

**Pourquoi `prepareThreshold = 0` ?** Par défaut, le driver JDBC « prépare » les requêtes répétées sur le serveur pour les réexécuter plus vite. Mais en mode transaction, le pooler peut envoyer chacune de vos requêtes sur une connexion serveur **différente** : la requête préparée sur l'une n'existe pas sur l'autre, d'où des erreurs `prepared statement "S_1" already exists` (ou `does not exist`). La valeur `0` désactive cette préparation. C'est l'équivalent du `prepare_threshold=None` utilisé avec `psycopg` dans les notebooks.

> 💡 **Recommandé** : dans l'onglet **Options**, cochez **Read-only**. DataGrip refusera alors toute requête de modification : pratique, car ce TP se fait en lecture seule (uniquement des `SELECT`).

## 4. Tester la connexion

1. Cliquez sur **Test Connection** (en bas de la fenêtre).
2. Vous devez voir **Succeeded** et une version de PostgreSQL (17.x). Sinon, voyez [Problèmes fréquents](#problèmes-fréquents).
3. Cliquez sur **OK** pour enregistrer la Data Source.

## 5. Onglet Schemas : ne garder que `public`

La base Supabase contient de nombreux schémas techniques (`auth`, `storage`, `realtime`…) qui ne nous servent pas et ralentissent l'affichage.

1. Rouvrez les propriétés de la Data Source (clic droit dessus → **Properties**, ou `F4`) puis l'onglet **Schemas**.
2. Dépliez la base `postgres` et ne cochez **que** le schéma **`public`**.
3. Validez avec **OK**. Dans le Database Explorer, dépliez `postgres → public` : vous voyez les tables (`pays`, `villes`, `ecoles`…) et les vues (`v_classement_classe`, `v_moyennes_eleves`).

## 6. Ouvrir le script du TP et l'attacher à la Data Source

1. **File → Open…** et choisissez le fichier `sql/01_postgres_datagrip.sql` du dépôt.
2. Attachez-le à la Data Source : en haut à droite de l'éditeur, cliquez sur le sélecteur de source de données (il affiche `<no data source>` tant que rien n'est attaché) et choisissez `Gestion scolaire (TP)`. Si vous lancez une requête sans l'avoir fait, DataGrip vous demande de choisir la source : même réponse.
3. Pour vos essais personnels (exercices), ouvrez plutôt une **console** : clic droit sur la Data Source → **New → Query Console**. Le fichier du TP reste ainsi intact.

## 7. Exécuter une requête : `Ctrl+Entrée`

1. Placez le curseur **n'importe où dans une requête** (entre son `SELECT` et son `;`).
2. Appuyez sur **`Ctrl+Entrée`** (**`Cmd+Entrée`** sur macOS), ou cliquez sur la flèche verte ▶ dans la marge.
3. Le résultat s'affiche dans un tableau en bas de l'écran. Seule la requête sous le curseur est exécutée.

> 💡 Si DataGrip propose une petite liste de fragments (la requête entière ou une partie), choisissez la **requête entière** (la ligne la plus longue).

> 💡 DataGrip n'affiche que les 500 premières lignes d'un résultat. Ce n'est pas un problème : sur une base partagée, on utilise de toute façon `LIMIT`, des filtres et des agrégats.

Avancez dans l'ordre du script : les lignes qui commencent par `--` sont des **commentaires** (les explications), PostgreSQL les ignore.

## 8. Exporter un résultat en CSV

Exemple : le tableau de bord 2025-2026 par pays (partie 10 du script), à envoyer à la direction.

1. Exécutez la requête : le résultat s'affiche en bas.
2. Dans la barre d'outils du résultat, cliquez sur le bouton **Export Data** (ou clic droit dans le tableau → **Export Data**).
3. Choisissez le format (**Extractor**) **CSV**, cochez l'ajout des noms de colonnes (*Add column header*) si besoin, puis indiquez le fichier de sortie, par exemple `data/processed/tableau_de_bord_2025-2026.csv` (le dossier `data/` n'est pas versionné).
4. Cliquez sur **Export to File**.

> ⚠️ **Minimisation (RGPD)** : n'exportez que les colonnes utiles. Pas d'e-mails ni de téléphones de parents dans un fichier qui circule, même si les données de ce TP sont fictives.

## 9. Voir le schéma de la base (diagramme)

1. Dans le Database Explorer, faites un clic droit sur le schéma **`public`**.
2. **Diagrams → Show Diagram** (raccourci `Ctrl+Alt+Shift+U`, ou `Cmd+Option+Shift+U` sur macOS).
3. DataGrip dessine toutes les tables avec leurs colonnes et des flèches pour les **clés étrangères** : par exemple `villes.pays_id → pays.id`, `ecoles.ville_id → villes.id`. C'est la carte qui permet d'écrire les jointures.

> 💡 Le même schéma, commenté en français (clés, contraintes `CHECK` et `UNIQUE`, index), est dans le fichier `docs/schema_postgres.sql` du dépôt. Ouvrez-le dans DataGrip pour le **lire**, mais ne l'exécutez pas : il contient des `CREATE TABLE`, et ce TP est en lecture seule.

## 10. Bonus : se connecter aussi à MongoDB

DataGrip sait aussi interroger la base MongoDB du TP (`ride_share_v1`, données de VTC et de livraison).

1. **`+` → Data Source → MongoDB**, nommez-la par exemple `Ride share (TP)`.
2. **Connection type** : choisissez **URL only**, puis collez dans le champ **URL** l'URI fournie par l'enseignant (la valeur de `MONGO_URI` dans votre `.env`, qui commence par `mongodb+srv://`). L'utilisateur et le mot de passe sont inclus dans l'URI : ne la copiez nulle part ailleurs.
3. Téléchargez le driver si DataGrip le propose, puis **Test Connection** → **OK**.
4. Onglet **Schemas** : ne cochez que la base **`ride_share_v1`**.
5. Clic droit sur la Data Source → **New → Query Console**, puis essayez (syntaxe du shell MongoDB, toujours avec une limite) :

```javascript
db.countries.find({}, {name: 1, isoCode: 1, currency: 1}).limit(5)
```

```javascript
db.trips.find({serviceType: "delivery"}, {amount: 1, currency: 1, requestedAt: 1}).limit(5)
```

> ⚠️ Mêmes règles qu'avec PostgreSQL : lecture seule (uniquement des `find` et des agrégations), toujours une **projection** (les champs voulus) et une **limite**. La collection `trips` contient plus de 330 000 documents.

## Problèmes fréquents

| Symptôme | Cause probable | Solution |
|---|---|---|
| `prepared statement "S_1" already exists` (ou `does not exist`) | `prepareThreshold` n'est pas réglé | Onglet **Advanced** : `prepareThreshold = 0`, puis déconnectez/reconnectez la Data Source (bouton **Disconnect** du Database Explorer) |
| `FATAL: Tenant or user not found` | Utilisateur incomplet, ou hôte d'une autre région | L'utilisateur doit être de la forme complète `postgres.<identifiant-projet>` ; vérifiez l'hôte caractère par caractère |
| `FATAL: password authentication failed` | Mot de passe erroné | Ressaisissez-le (attention aux espaces copiés en trop) |
| `FATAL: Max client connections reached` | Port 5432 (mode session, 15 clients maximum) | Utilisez le port **6543** |
| `Connection attempt timed out`, `UnknownHostException` | Mauvais hôte, ou réseau qui bloque le port 6543 | Utilisez l'hôte du **pooler** (pas `db.<projet>.supabase.co`, accessible seulement en IPv6) ; sur un Wi-Fi filtrant, essayez un autre réseau (partage de connexion du téléphone) |
| Erreur SSL ou connexion refusée en clair | SSL non activé | `sslmode = require` (onglet Advanced) ou **Use SSL** + mode **Require** (onglet SSH/SSL) |
| Des dizaines de schémas inconnus, affichage lent | Tous les schémas Supabase sont chargés | Onglet **Schemas** : ne cochez que `public` |
| `Ctrl+Entrée` ne fait rien, ou demande une source de données | Le fichier n'est pas attaché à la Data Source | Étape 6 : sélecteur en haut à droite de l'éditeur |
| Une requête tourne sans fin | Requête trop lourde (oubli de `LIMIT` ou de filtre sur `notes`) | Bouton carré rouge **Cancel** dans la barre des résultats, puis ajoutez un `LIMIT` ou un `WHERE` |
| La requête exécutée n'est pas celle attendue | Curseur hors de la requête, ou mauvais fragment choisi | Placez le curseur à l'intérieur de la requête, ou sélectionnez tout son texte avant `Ctrl+Entrée` |
| MongoDB : `Timed out … while waiting to connect` | Réseau bloqué ou adresse IP non autorisée par le serveur Atlas | Testez depuis un autre réseau et prévenez l'enseignant |
