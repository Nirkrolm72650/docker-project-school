# E-Commerce Cloud Platform — LocalStack & Terraform (`migration-cloud`)

Plateforme e-commerce multi-services conteneurisée et migrée vers une architecture cloud **AWS émulée sous LocalStack**, entièrement modélisée et provisionnée en **Infrastructure as Code (IaC)** avec **Terraform** (`tflocal`).

Ce dépôt contient le code applicatif ainsi que le livrable d'évaluation officiel dans le dossier [migration-cloud/](file:///Users/brandon/Desktop/docker-project-school/migration-cloud/).

---

## 🏛️ Architecture Cloud (LocalStack)

L'application s'appuie sur une infrastructure AWS complète provisionnée via Terraform :

```
+-----------------------------------------------------------------------------------+
| LOCALSTACK GATEWAY (http://localhost:4566)                                        |
|                                                                                   |
|  +-----------------------------------------------------------------------------+  |
|  | VPC : ecom-vpc (10.0.0.0/16) - DNS Hostnames & Support Enabled              |  |
|  |                                                                             |  |
|  |  +-----------------------------------------------------------------------+  |  |
|  |  | Subnet : ecom-subnet (10.0.1.0/24) - us-east-1a                          |  |  |
|  |  | Security Group Unique : ecom-sg                                         |  |  |
|  |  |   - Ingress Public (0.0.0.0/0) : Port 8080 (Frontend) & 3000 (Backend)   |  |  |
|  |  |   - Ingress Interne (self = true) : Port 5432 (Postgres) & 4000 (PDF)   |  |  |
|  |  |                                                                       |  |  |
|  |  |  [EC2: ecom-frontend]       [EC2: ecom-backend]                       |  |  |
|  |  |  - Nginx UI (Port 8080)     - API REST (Port 3000)                    |  |  |
|  |  |                             - IAM Profile: ecom-instance-profile      |  |  |
|  |  |                                                                       |  |  |
|  |  |  [EC2: ecom-pdf-service]    [EC2: ecom-worker]    [EC2: ecom-postgres]|  |  |
|  |  |  - Rendu PDF (Port 4000)    - Worker asynchrone   - Port 5432         |  |  |
|  |  |                                                   - Disque EBS:       |  |  |
|  |  |                                                     ecom-pgdata (10G) |  |  |
|  |  +-----------------------------------|-----------------------------------+  |  |
|  +--------------------------------------|--------------------------------------+  |
|                                         |                                         |
|                                         v IAM Role: ecom-role (s3:Put, Get, List) |
|  +-----------------------------------------------------------------------------+  |
|  | S3 BUCKET : ecom-invoices                                                   |  |
|  | └── invoices/  (Factures PDF générées automatiquement à chaque commande)     |  |
|  +-----------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------+
```

---

## 📦 Composants Provisionnés par Terraform

| Ressource AWS | Nom / Identifiant | Description |
|---|---|---|
| **VPC** | `ecom-vpc` (`10.0.0.0/16`) | Réseau virtuel isolé avec résolution DNS activée via `modules/reseau` |
| **Subnet** | `ecom-subnet` (`10.0.1.0/24`) | Sous-réseau hébergeant l'ensemble des instances applicatives |
| **Security Group** | `ecom-sg` | **Public** : 8080, 3000 (`0.0.0.0/0`) \| **Interne** : 5432, 4000 (`self = true`) |
| **IAM Role & Policy** | `ecom-role` / `ecom-s3-policy` | Rôle EC2 avec droits de lecture/écriture restreints sur le bucket S3 |
| **Instance Profile** | `ecom-instance-profile` | Profil d'instance rattaché uniquement au serveur backend |
| **S3 Bucket** | `ecom-invoices` | Stockage persistant des factures PDF de commande |
| **5 Instances EC2** | `ecom-*` | Une instance par service (`frontend`, `backend`, `pdf-service`, `postgres`, `worker`) |
| **Volume EBS** | `ecom-pgdata` | Disque de 10 Go attaché sur `/dev/sdh` à l'instance PostgreSQL |

---

## 🚀 Démarrage Rapide

### 1. Prérequis : Démarrer LocalStack
LocalStack émule les services AWS et **doit être démarré en premier** sur le port `4566` :

```bash
# Vérifier si LocalStack tourne déjà :
docker ps --filter name=localstack

# Si LocalStack n'est pas démarré, le lancer avec la CLI :
localstack start -d
# Ou directement via Docker :
docker run -d -p 4566:4566 -e LOCALSTACK_AUTH_TOKEN=<VOTRE_TOKEN> --name localstack-aws localstack/localstack
```

*Outils requis : Docker Desktop, `tflocal` et `awslocal`.*

### 2. Configuration d'environnement
Copier le fichier d'exemple si ce n'est pas déjà fait :
```bash
cp .env.example .env
```

### 3. Provisionnement de l'infrastructure Cloud (`migration-cloud`)
```bash
cd migration-cloud
tflocal init
tflocal apply -auto-approve
cd ..
```

### 4. Lancement des conteneurs applicatifs
```bash
docker compose up -d --build
```

---

## 🔍 Audit & Vérification des Ressources (`awslocal`)

Vous pouvez exécuter directement les 4 commandes de vérification de l'Étape 6 du Capstone :

1. **Vérifier les 5 instances EC2 en statut `running` :**
   ```bash
   awslocal ec2 describe-instances \
     --filters "Name=tag:Project,Values=ecom" \
     --query 'Reservations[].Instances[].{Nom:Tags[?Key==`Name`]|[0].Value,Etat:State.Name,Type:InstanceType}' \
     --output table
   ```

2. **Vérifier le Security Group (Public `0.0.0.0/0` vs Interne `self = true`) :**
   ```bash
   awslocal ec2 describe-security-groups \
     --filters "Name=group-name,Values=ecom-sg" \
     --query 'SecurityGroups[0].IpPermissions[].{Port:FromPort,Public:IpRanges[0].CidrIp,Interne:UserIdGroupPairs[0].GroupId}' \
     --output table
   ```

3. **Vérifier le bucket S3 et le volume EBS attaché à Postgres :**
   ```bash
   awslocal s3 ls
   awslocal ec2 describe-volumes \
     --query 'Volumes[].{Id:VolumeId,Taille:Size,Attache:Attachments[0].InstanceId}' \
     --output table
   ```

4. **Vérifier l'état Terraform :**
   ```bash
   cd migration-cloud
   tflocal state list
   tflocal output
   cd ..
   ```

---

## 🛒 Tester le Cycle de Commande et l'Intégration S3

1. **Vérifier la santé du bucket S3 depuis le backend :**
   ```bash
   curl http://localhost:3000/api/aws/status
   ```
   *Réponse attendue :*
   ```json
   {
     "status": "online",
     "aws_region": "us-east-1",
     "aws_endpoint": "http://localhost:4566",
     "s3_bucket": "ecom-invoices",
     "s3_healthy": true
   }
   ```

2. **Se connecter pour obtenir un token JWT :**
   ```bash
   TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/login \
     -H "Content-Type: application/json" \
     -d '{"email":"admin@test.com","password":"admin123"}' | grep -o '"token":"[^"]*' | cut -d'"' -f4)
   ```

3. **Passer une commande :**
   ```bash
   curl -X POST http://localhost:3000/api/orders \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $TOKEN" \
     -d '{"items": [{"product_id": 1, "quantity": 1}], "shipping_address": "12 rue de la Paix, Paris"}'
   ```
   *L'API fait appel au micro-service PDF, génère la facture et la téléverse automatiquement vers S3 LocalStack (`invoices/facture-<ID>.pdf`).*

4. **Télécharger la facture officielle directement depuis S3 :**
   ```bash
   curl -O -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/orders/1/invoice
   ```

5. **Accéder à l'interface d'administration :**
   - Ouvrir **http://localhost:8080/admin.html**
   - Se connecter avec `admin@test.com` / `admin123`
   - Dans le tableau des commandes, cliquer sur **"📄 Télécharger (S3)"** pour récupérer la facture PDF stockée sur LocalStack.

---

## 🔄 Recommencer tout de zéro (Reset complet)

Pour faire table rase et reconstruire l'ensemble de l'infrastructure Cloud et de l'application :

### 1. Tout détruire et nettoyer
```bash
# Détruire l'infrastructure Terraform
cd migration-cloud && tflocal destroy -auto-approve && cd ..

# Supprimer les conteneurs et volumes applicatifs
docker compose down -v

# Redémarrer LocalStack pour vider son état
docker restart localstack-aws
```

### 2. Tout relancer
```bash
# Provisionner l'infrastructure Cloud avec Terraform
cd migration-cloud && tflocal init && tflocal apply -auto-approve && cd ..

# Lancer l'application conteneurisée
docker compose up -d --build
```

---

## 📂 Contenu du Rendu & Documentation

- [migration-cloud/](file:///Users/brandon/Desktop/docker-project-school/migration-cloud/) : Dossier officiel d'évaluation du Capstone :
  - `INVENTAIRE.md` : Tableau des services, réseau, stockage et stratégies de migration.
  - `main.tf` : Code Terraform complet (Sections 4.1 à 4.8).
  - `modules/reseau/` : Module réutilisable VPC + Subnet.
  - `PREUVES.md` : Sorties réelles des commandes d'audit.
  - `README.md` : Instructions de démarrage concises.
- [oral.md](file:///Users/brandon/Desktop/docker-project-school/oral.md) : Fiche de révision et support de soutenance pour l'oral (pitch, démonstration, questions pièges et passage au vrai AWS).