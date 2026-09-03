# Inventaire de l'application & Stratégie de Migration Cloud

**Nom du projet :** `ecom`  
**Environnement :** `dev`

---

## Étape 1 — Inventorier l'application existante

### 1.1 Tableau des services (issu de `docker-compose.yml`)

| Service (nom compose) | Rôle en une phrase | Port(s) exposés | Joignable depuis internet ? | Dépend de | Volume nommé ? | Accède à du stockage ? |
|---|---|---|---|---|---|---|
| `frontend` | Interface web client et back-office administrateur servie par Nginx | 8080 (8080:80) | **oui** (consultée par un utilisateur humain via navigateur) | `backend` | — | non |
| `backend` | API REST Node.js/Express (catalogue, auth JWT, commandes, factures) | 3000 (3000:3000) | **oui** (API publique consommée par le frontend et clients) | `postgres`, `pdf-service` | — | **oui** (téléversement et lecture des factures PDF S3) |
| `pdf-service` | Micro-service interne dédié à la génération binaire des factures PDF | 4000 (4000:4000) | **non** (service interne appelé uniquement par le backend) | — | — | non |
| `postgres` | Base de données relationnelle persistante PostgreSQL 18 | 5432 | **non** (service de données strictement interne) | — | oui (`pgdata`) | non |
| `worker` | Traitement asynchrone des commandes en attente en tâche de fond | — | **non** (worker interne sans port d'écoute) | `postgres` | — | non |

---

### 1.3 Tableau du réseau et du stockage

| Élément Docker | Où le trouver dans le compose | Équivalent cloud AWS |
|---|---|---|
| Réseaux (`networks:`) | `back-net`, `front-net` | 1 VPC (`ecom-vpc`) + 1 Subnet (`ecom-subnet`) via `module "reseau"` |
| Volume nommé `pgdata` | Section `volumes:` en bas du compose | 1 `aws_ebs_volume` (`ecom-pgdata`) + 1 `aws_volume_attachment` |
| Factures PDF durables | Logique de commande dans le code | 1 bucket S3 (`ecom-invoices`) + 1 rôle IAM (`ecom-role`) |

---

## Étape 2 — Choisir une stratégie par composant

| Service | Stratégie | Justification (1 phrase) |
|---|---|---|
| `frontend` | **rehost** | L'interface web Nginx est stable et conteneurisée, migrée directement sur une instance EC2. |
| `backend` | **rehost** | L'API Node.js tourne telle quelle, migrée sur une instance EC2 avec rôle IAM pour l'accès S3. |
| `pdf-service` | **rehost** | Micro-service interne sans état dédié au rendu PDF, migré directement sur une instance EC2 interne. |
| `postgres` | **replatform** *(codé en rehost)* | Une base managée (ex: AWS RDS) gérerait sauvegardes et haute disponibilité ; indisponible sur LocalStack Hobby, donc migrée en instance EC2 avec volume EBS persistant. |
| `worker` | **rehost** | Le worker asynchrone consomme les commandes en continu, migré sur une instance EC2 dédiée. |

> **Bilan pour Terraform :** 5 instances EC2 à provisionner (`frontend`, `backend`, `pdf_service`, `postgres`, `worker`), 1 bucket S3 pour les factures, 1 rôle IAM pour le backend, et 1 volume EBS pour la persistance de PostgreSQL.
