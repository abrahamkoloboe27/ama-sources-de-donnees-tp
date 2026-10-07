# Base MongoDB `ride_share_v1` — fiche de référence

Application fictive de **VTC, livraison et location** présente dans **19 pays africains**.
Base de type **document** : chaque enregistrement est un document JSON (BSON), rangé dans une **collection**.

> ⚠️ Base partagée pendant le TP : on ne fait **que lire** (`find`, `count_documents`, `distinct`, `aggregate`).
> Jamais d'`insert`, `update`, `delete`, `drop` ou `create_index`.

## Vocabulaire SQL ↔ MongoDB

| SQL (PostgreSQL) | MongoDB |
|---|---|
| base de données | base de données |
| table | collection |
| ligne | document |
| colonne | champ |
| clé primaire `id` | `_id` (souvent un `ObjectId`) |
| `WHERE` | filtre de `find()` ou étape `$match` |
| `GROUP BY` | étape `$group` |
| `ORDER BY` / `LIMIT` | `.sort()` / `.limit()` ou `$sort` / `$limit` |
| `JOIN` | étape `$lookup` |

## Les collections

| Collection | Documents | Contenu |
|---|---:|---|
| `trips` | 335 459 | les courses (VTC, livraison, location) |
| `ratings` | 670 918 | les notes : 2 par course (le client note le chauffeur, le chauffeur note le client) |
| `users` | 20 247 | les clients |
| `drivers` | 2 647 | les chauffeurs |
| `vehicles` | 3 254 | les véhicules |
| `maintenance` | 12 528 | les opérations d'entretien des véhicules |
| `cities` | 8 214 | les villes |
| `countries` | 19 | les pays |

Seul `_id` est indexé dans chaque collection.

## Les liens entre collections

Il n'y a pas de clé étrangère imposée par la base : les liens sont de simples champs contenant un `ObjectId`.

```
countries ←─ cities ←─┬─ users ←──────── trips ─→ drivers ─→ vehicles ←─ maintenance
   ↑          ↑       └─ drivers            │
   └──────────┴─ (countryId, cityId)        └─← ratings (tripId)
```

| Champ | Pointe vers |
|---|---|
| `cities.countryId` | `countries._id` |
| `users.countryId`, `users.cityId` | `countries._id`, `cities._id` |
| `drivers.countryId`, `drivers.cityId`, `drivers.userId` | `countries._id`, `cities._id`, `users._id` |
| `vehicles.driverId` | `drivers._id` |
| `maintenance.vehicleId` | `vehicles._id` |
| `trips.userId`, `trips.driverId`, `trips.vehicleId` | `users._id`, `drivers._id`, `vehicles._id` |
| `ratings.tripId` | `trips._id` |
| `ratings.givenById`, `ratings.toId` | un `users._id` ou un `drivers._id` selon `givenBy` / `toType` |

## Exemple de document `trips`

```json
{
  "_id": ObjectId("68932b9d00600df87ac544b0"),
  "serviceType": "delivery",                     // ride | delivery | rental
  "userId": ObjectId("..."), "driverId": ObjectId("..."), "vehicleId": ObjectId("..."),
  "origin":      { "type": "Point", "coordinates": [161.698341, 0.8624595] },   // [longitude, latitude]
  "destination": { "type": "Point", "coordinates": [161.033501, -14.1363665] },
  "requestedAt": ISODate("2025-09-03T19:29:07.512Z"),
  "acceptedAt":  ISODate("2025-09-03T19:33:19.512Z"),
  "startedAt":   ISODate("2025-09-03T19:36:28.512Z"),
  "endedAt":     ISODate("2025-09-03T20:11:43.512Z"),
  "status": "completed",
  "currency": "XOF",
  "amount": 1485.93,
  "fare": { "amount": 1485.93, "currency": "XOF",
            "breakdown": { "base": 317.72, "distance": 1376.93, "time": 282.13 } },
  "serviceDetails": { "rentalDurationMins": null, "packageWeightKg": 20.69 }
}
```

## Champs et valeurs utiles

| Collection | Champ | Valeurs |
|---|---|---|
| `trips` | `serviceType` | `ride`, `delivery`, `rental` (≈ 1/3 chacun) |
| `trips` | `status` | toujours `completed` |
| `trips` | `currency` | `NGN`, `XOF`, `KES`, `SLL`, `GHS`, `XAF`, `CDF` |
| `trips` | `requestedAt` | du 12/12/2023 au 04/12/2025 (forte croissance ; décembre 2025 incomplet) |
| `drivers` | `status` | `active`, `inactive`, `suspended`, `banned` |
| `vehicles` | `type` / `status` | `car`, `van`, `bike`, `tricycle` / `active`, `maintenance`, `sold`, `decommissioned` |
| `maintenance` | `type` | `repair`, `replacement`, `routine_check` |
| `ratings` | `givenBy` / `stars` | `user`, `driver` / 1 à 5 |
| `countries` | `isoCode` | code ISO à 2 lettres (`BJ`, `SN`, `TG`, `CI`, `NG`, `GH`, `KE`…) : **la bonne clé pour croiser avec d'autres sources** |

## ⚠️ Pièges de qualité (la « véracité » du cours)

1. **Plusieurs devises** : `amount` est exprimé dans 7 monnaies différentes. Ne jamais additionner tous les montants ensemble : toujours regrouper par `currency`.
2. **Villes orphelines** : seules **241** villes pointent vers un pays existant ; **7 973** ont un `countryId` qui ne correspond à aucun pays (reste d'un ancien chargement). Les clients et chauffeurs n'utilisent que les 241 villes valides.
3. **Coordonnées GPS incohérentes** : `origin` et `destination` sont générées au hasard, elles ne correspondent pas aux villes.
4. **Schéma souple** : `serviceDetails.packageWeightKg` n'est renseigné que pour les livraisons ; ailleurs il vaut `null`.
5. **Noms de pays non normalisés** : `Bénin` (en français) côtoie `Senegal` et `Cameroon` (en anglais). Pour croiser avec une autre source, on utilise `isoCode`, pas le nom.

## Se connecter

```python
import os
from dotenv import load_dotenv
from pymongo import MongoClient

load_dotenv()
client = MongoClient(os.getenv("MONGO_URI"), serverSelectionTimeoutMS=10000)
db = client[os.getenv("MONGO_DB")]
print(db.list_collection_names())
client.close()
```

Outils graphiques : **MongoDB Compass** (gratuit) ou **DataGrip** (Data Source → MongoDB, coller l'URI du `.env`).
