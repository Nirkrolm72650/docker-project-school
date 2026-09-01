# E-Commerce Multi-Services Docker

## Description
Une application e-commerce complète orchestrée par Docker, composée d'une API de gestion, d'un catalogue produits, d'un système d'authentification JWT, d'un worker de traitement asynchrone des commandes et d'une interface web moderne.

## Prérequis
- Docker Desktop récent avec `docker compose` (v2) fonctionnel

Dupliquez le fichier .env.example en un fichier .env et renseignez vos propres identifiants si vous souhaitez tester l'envoi d'e-mails, bien que le worker simule le traitement des commandes par défaut.

## Démarrage
```bash
docker compose up -d --build
```

## Services

| Service  | Port | Rôle |
|----------|------|------|
| backend  | 3000 | API REST (Gestion des produits, authentification et commandes)
| worker   | —    | Traitement asynchrone des commandes en arrière-plan
| frontend | 8080 | Interface web client et espace administrateur
| postgres | —    | Base de données relationnelle PostgreSQL 18 (non exposée)

## Vérifier que tout fonctionne
1. Ouvrir **http://localhost:8080** pour accéder au catalogue et tester l'interface.
2. Effectuer une requête de test `curl` pour simuler une création de commande :
   ```bash
   curl -X POST http://localhost:3000/api/orders \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer VOTRE_TOKEN_JWT" \
     -d '{"items": [{"product_id": 1, "quantity": 1}], "shipping_address": "12 rue de la Paix, Paris"}'
   ```
3. Pour tester l'API via Postman :
   - Effectuer d'abord une requête `POST /api/auth/login` (ou /api/auth/register) pour récupérer un **Token JWT**.
   - Ajouter l'en-tête `Authorization: Bearer <votre_token>` dans vos requêtes protégées (comme `GET /api/orders`, qui filtre automatiquement les commandes de l'utilisateur connecté).

4. Rafraîchir l'interface admin pour vérifier que la commande apparaît.

5. Consulter les logs du worker pour valider son traitement asynchrone :
   ```bash
   docker compose logs worker
   ```

## Arrêt
```bash
docker compose down        # Arrête tous les conteneurs et réseaux
docker compose down -v     # Arrête tout et supprime les données persistées du volume
```