# E-Commerce Cloud Platform - LocalStack & Terraform

Plateforme e-commerce conteneurisée et migrée vers une infrastructure cloud locale **AWS / LocalStack**, entièrement modélisée et provisionnée en **Infrastructure as Code (IaC)** avec **Terraform**.

---

## 🏛️ Architecture Cloud (LocalStack)

L'application s'appuie sur une infrastructure AWS complète émulée par LocalStack :

```
+-----------------------------------------------------------------------------------+
| LOCALSTACK GATEWAY (http://localhost:4566)                                        |
|                                                                                   |
|  +-----------------------------------------------------------------------------+  |
|  | VPC : ecom-vpc (10.0.0.0/16) - DNS Hostnames & Support Enabled              |  |
|  | Internet Gateway : ecom-igw                                                 |  |
|  |                                                                             |  |
|  |  +-------------------------------------+ +-------------------------------+  |  |
|  |  | Public Subnet (10.0.1.0/24)         | | Private Subnet (10.0.2.0/24)      |  |  |
|  |  | AZ: us-east-1a                      | | AZ: us-east-1b                    |  |  |
|  |  | Route Table -> IGW (0.0.0.0/0)      | | Table de routage interne          |  |  |
|  |  |                                     | |                               |  |  |
|  |  |  [EC2: ecom-web-app]                | |  [EC2: ecom-database]         |  |  |
|  |  |  - IP: 10.0.1.4 (Public IP dispo)   | |  - IP: 10.0.2.4 (Isolée)      |  |  |
|  |  |  - Frontend Web (Port 80/8080)      | |  - PostgreSQL (Port 5432)     |  |  |
|  |  |  - Backend API (Port 3000)          | |  - SG: ecom-db-sg             |  |  |
|  |  |  - Worker asynchrone                | |    (Ingress réservé Backend)  |  |  |
|  |  |  - SG: frontend-sg & backend-sg     | +-------------------------------+  |  |
|  |  |  - IAM Profile: ec2-profile         |                                    |  |
|  |  +-----------------|-------------------+                                    |  |
|  +--------------------|--------------------------------------------------------+  |
|                       |                                                           |
|                       v IAM Role & Policy (s3:PutObject, s3:GetObject, s3:List)   |
|  +-----------------------------------------------------------------------------+  |
|  | S3 BUCKET : ecom-localstack-storage                                         |  |
|  | ├── invoices/  (Factures PDF générées automatiquement à la commande)        |  |
|  | └── products/  (Assets et images des articles)                              |  |
|  +-----------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------+
```

---

## 📦 Composants Provisionnés par Terraform

| Ressource AWS | Nom / Identifiant | Description |
|---|---|---|
| **VPC** | `ecom-vpc` (`10.0.0.0/16`) | Réseau virtuel isolé avec résolution DNS activée |
| **Subnet Public** | `ecom-public-subnet` (`10.0.1.0/24`) | Héberge les points d'accès Web et API |
| **Subnet Privé** | `ecom-private-subnet` (`10.0.2.0/24`) | Héberge la base de données PostgreSQL |
| **Internet Gateway** | `ecom-igw` | Passerelle de sortie Internet pour le sous-réseau public |
| **Security Group** | `ecom-frontend-sg` | Ports autorisés : 80, 8080, 22 (SSH) |
| **Security Group** | `ecom-backend-sg` | Port 3000 (API REST) et 22 |
| **Security Group** | `ecom-db-sg` | Port 5432 autorisé strictement depuis le `backend-sg` |
| **IAM Role & Policy** | `ecom-ec2-role` / `ecom-s3-access-policy` | Rôle EC2 avec droits de lecture/écriture sur S3 |
| **Instance Profile** | `ecom-ec2-instance-profile` | Profil d'instance associé aux serveurs EC2 |
| **S3 Bucket** | `ecom-invoices` | Stockage des factures PDF (`invoices/`) et médias |
| **EC2 Web & App** | `ecom-web-app` | Instance hébergeant Frontend, API et Worker |
| **EC2 Database** | `ecom-database` | Instance hébergeant la base de données PostgreSQL |
| **Key Pair** | `ecom-deployer-key` | Clé SSH OpenSSH pour la gestion des instances |

---

## 🚀 Démarrage Rapide

### 1. Prérequis
- Docker Desktop en cours d'exécution.
- LocalStack actif sur le port `4566` (via votre conteneur `localstack-aws` ou `docker compose up -d localstack`).
- Terraform (v1.5+) et `awslocal` (optionnel mais recommandé).

### 2. Configuration d'environnement
Copier le fichier d'exemple si ce n'est pas déjà fait :
```bash
cp .env.example .env
```

### 3. Provisionnement de l'infrastructure Cloud avec Terraform
Exécuter le script de déploiement automatique :
```bash
./scripts/deploy.sh
```
*Ou manuellement via Terraform :*
```bash
terraform -chdir=terraform init
terraform -chdir=terraform apply -auto-approve
```

### 4. Lancement des conteneurs applicatifs
```bash
docker compose up -d --build
```

---

## 🔍 Audit & Vérification des Ressources (`awslocal`)

Un script de vérification complet est disponible :
```bash
./scripts/verify.sh
```

Ou vous pouvez interroger directement LocalStack avec les commandes AWS CLI :

- **Vérifier les instances EC2 en cours d'exécution :**
  ```bash
  awslocal ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key=='Name'].Value|[0],PrivateIpAddress,PublicIpAddress]" --output table
  ```

- **Vérifier le VPC et les Subnets :**
  ```bash
  awslocal ec2 describe-vpcs --filters "Name=tag:Name,Values=ecom-vpc"
  awslocal ec2 describe-subnets --filters "Name=tag:ManagedBy,Values=Terraform"
  ```

- **Vérifier les Security Groups :**
  ```bash
  awslocal ec2 describe-security-groups --filters "Name=group-name,Values=ecom-*"
  ```

- **Vérifier le rôle IAM et le profil d'instance :**
  ```bash
  awslocal iam list-roles --query "Roles[?RoleName=='ecom-ec2-role']"
  awslocal iam list-instance-profiles
  ```

- **Lister le contenu du Bucket S3 et les factures :**
  ```bash
  awslocal s3 ls
  awslocal s3 ls s3://ecom-localstack-storage/invoices/
  ```

---

## 🛒 Tester le Cycle de Commande et l'Intégration S3

1. **Vérifier le statut de l'intégration AWS / S3 via l'API :**
   ```bash
   curl http://localhost:3000/api/aws/status
   ```
   *Réponse attendue :*
   ```json
   {
     "status": "online",
     "aws_region": "us-east-1",
     "aws_endpoint": "http://localhost:4566",
     "s3_bucket": "ecom-localstack-storage",
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
   *L'API génère automatiquement la facture PDF et la téléverse vers S3 LocalStack (`invoices/facture-<ID>.pdf`).*

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

## 🛑 Arrêt & Nettoyage

- Arrêter les conteneurs :
  ```bash
  docker compose down
  ```
- Détruire l'infrastructure Terraform :
  ```bash
  cd migration-cloud && tflocal destroy -auto-approve
  ```