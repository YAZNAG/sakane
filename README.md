# Sakane — agence immobilière

Copie de l'application Alwed pour l'agence **Sakane**, avec tous ses modules :
biens, réservations, calendrier, Airbnb, clients, propriétaires, charges,
réclamations, caisse, statistiques, campagnes WhatsApp, syndics, modèles de
messages, droits et permissions, location longue durée (baux) et vente
(mandats, reçus de visite).

## Organisation

- `backend/` — API Laravel 12 (PHP 8.3, MySQL 8).
- `mobile/immobilier-sakane/` — application Flutter (Android), paquet `com.se.sakane`.

## Production

- API : https://api.sakane.optizaworks.com (serveur 93.127.186.28, HestiaCP).
- Base : `saadev_sakane_db`, document racine lié à `backend/public`.
- Le fichier `.env` n'est pas versionné : il est propre à chaque installation.

## Démarrage

```bash
cd backend && composer install && php artisan migrate --force
cd mobile/immobilier-sakane && flutter pub get && flutter build apk --release
```

L'adresse de l'API se règle dans `mobile/immobilier-sakane/lib/config.dart`.
