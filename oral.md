# 🎓 Guide de Présentation Orale - Architecture E-Commerce, LocalStack & Migration AWS

Ce document est conçu comme votre fiche de révision et support complet pour votre soutenance/oral. Il détaille l'ensemble du projet, les choix techniques, l'Infrastructure as Code (Terraform), l'émulation avec LocalStack, et la feuille de route pour une mise en production sur le vrai Cloud AWS.

---

## 📋 Table des Matières
1. [Pitch du Projet & Contexte (1-2 min)](#1-pitch-du-projet--contexte)
2. [Architecture Fonctionnelle de l'Application](#2-architecture-fonctionnelle-de-lapplication)
3. [L'Infrastructure as Code avec Terraform](#3-linfrastructure-as-code-avec-terraform)
4. [L'Émulation Cloud avec LocalStack](#4-lémulation-cloud-avec-localstack)
5. [Intégration Applicative : Le Stockage S3 & Micro-Services](#5-intégration-applicative--le-stockage-s3--micro-services)
6. [Passage au Vrai Cloud AWS (Production) : Ce qui change](#6-passage-au-vrai-cloud-aws-production--ce-qui-change)
7. [Plan Type pour l'Oral (10-15 min)](#7-plan-type-pour-loral)
8. [Questions Pièges du Jury & Réponses Types](#8-questions-pièges-du-jury--réponses-types)

---

## 1. Pitch du Projet & Contexte

### Phrase d'accroche pour démarrer :
> *"Dans le cadre de ce projet, j'ai fait évoluer une application e-commerce conteneurisée classique vers une architecture Cloud-Ready modélisée en Infrastructure as Code (IaC) avec Terraform et testée localement sur LocalStack. Mon objectif a été d'adopter les standards industriels d'AWS : segmentation réseau en VPC et sous-réseaux public/privé, sécurisation par Security Groups, gestion fine des identités avec IAM, et intégration du stockage objet S3."*

### Problématique résolue :
- **Avant** : Une application monolithique ou multi-conteneurs exécutée en local sur Docker sans notions réseau cloud, avec du stockage de fichiers temporaire sur le système de fichiers local et aucun standard de déploiement cloud.
- **Après** : Une infrastructure réseau et cloud reproductible en une seule commande (`terraform apply`), zéro coût d'expérimentation grâce à LocalStack, et une application connectée aux services managés (S3, IAM, EC2).

---

## 2. Architecture Fonctionnelle de l'Application

L'application est découpée en micro-services conteneurisés avec Docker :

| Service | Rôle Technique | Port / Exposition |
|---|---|---|
| **Frontend** | Interface web client et tableau de bord administrateur (HTML5, Tailwind CSS, JavaScript Vanilla, servi par Nginx). | `8080:80` |
| **Backend API** | API REST (Node.js, Express) gérant l'authentification JWT, le catalogue produits, les commandes et les routes d'administration. | `3000:3000` |
| **Micro-service PDF** | Service dédié générant les factures PDF officielles à l'aide de `pdfkit`. Reçoit les données de commande et renvoie un flux PDF binaire. | `4000:4000` (interne) |
| **PostgreSQL** | Base de données relationnelle persistante (PostgreSQL 18) contenant les utilisateurs, catégories, produits, commandes et lignes de commande. | `5432` (non exposé) |
| **Worker Asynchrone** | Traitement en tâche de fond (Background Worker) qui scrute les commandes en statut `pending`, simule le traitement logistique et met à jour leur statut en `processed`. | Aucun port externe |
| **LocalStack** | Émulateur Cloud AWS local exécutant EC2, S3, IAM, STS, VPC. | `4566` |

### Le Cycle de Vie d'une Commande (Workflow de bout en bout) :
1. **Sélection & Validation** : Le client choisit ses articles sur le frontend (`http://localhost:8080`) et valide son panier.
2. **Transaction SQL** : Le backend reçoit la requête `POST /api/orders`, ouvre une transaction PostgreSQL (`BEGIN`), vérifie les stocks, décrémente les stocks et insère la commande en base avec le statut `pending`.
3. **Génération de la Facture (Micro-service)** : Le backend appelle en HTTP interne le service `pdf-service:4000/generate-invoice` pour fabriquer la facture PDF.
4. **Persistance Cloud (S3)** : Le buffer PDF reçu est immédiatement poussé dans le bucket S3 `ecom-localstack-storage/invoices/facture-<ID>.pdf` via le SDK AWS.
5. **Notification** : Le client reçoit une confirmation par e-mail avec sa facture attachée.
6. **Consultation & Téléchargement** : Le client ou l'administrateur peut à tout moment télécharger sa facture officielle directement depuis S3 via l'endpoint `GET /api/orders/:id/invoice` ou depuis le panneau d'administration.
7. **Traitement Asynchrone** : Le worker en arrière-plan détecte la commande et passe son statut à `processed`.

---

## 3. L'Infrastructure as Code avec Terraform

L'ensemble des ressources cloud est défini de manière déclarative dans le dossier `terraform/`.

### Structure des fichiers Terraform :
- **`provider.tf`** : Déclare le provider AWS de HashiCorp (`hashicorp/aws ~> 5.0`). C'est ici que nous pointons les endpoints AWS (`ec2`, `s3`, `iam`, `sts`) vers `http://localhost:4566`.
- **`variables.tf` & `terraform.tfvars`** : Paramétrage dynamique (CIDR des réseaux, région `us-east-1`, nom du bucket S3, type d'instance `t3.micro`).
- **`vpc.tf`** : Conception du réseau :
  - **VPC** (`10.0.0.0/16`) : Isolation complète de l'environnement avec DNS activé.
  - **Internet Gateway (IGW)** : Permet aux ressources du sous-réseau public de communiquer avec l'extérieur.
  - **Subnet Public** (`10.0.1.0/24`, AZ `us-east-1a`) : Héberge les points d'entrée (Frontend et Backend).
  - **Subnet Privé** (`10.0.2.0/24`, AZ `us-east-1b`) : Héberge la base de données PostgreSQL, totalement inaccessible depuis Internet.
  - **Route Tables** : Table publique routant le trafic `0.0.0.0/0` vers l'IGW et table privée isolée.
- **`security_groups.tf`** : Application du principe de défense en profondeur :
  - `ecom-frontend-sg` : Ouvre les ports 80/8080 (Web) et 22 (SSH).
  - `ecom-backend-sg` : Ouvre le port 3000 depuis le Frontend et le port 22.
  - `ecom-db-sg` : Autorise le port 5432 **uniquement et strictement** depuis `ecom-backend-sg`. Impossible d'interroger directement la base depuis l'extérieur.
- **`iam.tf`** : Gestion des accès sans clés en dur :
  - `ecom-ec2-role` : Rôle assumable par le service EC2 (`sts:AssumeRole`).
  - `ecom-s3-access-policy` : Stratégie restreinte aux seules actions requises (`s3:PutObject`, `s3:GetObject`, `s3:ListBucket`).
  - `ecom-ec2-instance-profile` : Profil d'instance attaché aux machines virtuelles pour leur conférer automatiquement les droits S3.
- **`s3.tf`** : Bucket `ecom-localstack-storage` avec préfixes `invoices/` et `products/`.
- **`ec2.tf`** :
  - `aws_instance.web_app` : Déployée dans le sous-réseau public avec les SG Frontend et Backend et le profil IAM.
  - `aws_instance.database` : Déployée dans le sous-réseau privé avec le SG Database.
  - `user_data` : Scripts d'amorçage (cloud-init) automatisant l'installation et le démarrage des services Docker.
  - `aws_key_pair` : Clé SSH OpenSSH pour l'accès aux serveurs.
- **`outputs.tf`** : Exportation des IDs, IPs et ARN créés pour automatisation et audit.

---

## 4. L'Émulation Cloud avec LocalStack

### Pourquoi LocalStack ?
- **Coût zéro** : Développer et tester une architecture cloud complexe sans facture AWS.
- **Vitesse & Feedback immédiat** : Déploiement et destruction des ressources en quelques secondes.
- **Sécurité** : Aucun risque de laisser traîner des identifiants cloud en clair ou d'oublier des ressources allumées.
- **Conformité API** : LocalStack réplique exactement les APIs officielles d'Amazon Web Services.

### Comment vérifier l'état avec `awslocal` :
`awslocal` est un wrapper de l'AWS CLI officielle qui injecte automatiquement `--endpoint-url=http://localhost:4566`.
- Vérifier les instances EC2 :
  ```bash
  awslocal ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key=='Name'].Value|[0],PrivateIpAddress,PublicIpAddress]" --output table
  ```
- Vérifier les buckets S3 et les factures :
  ```bash
  awslocal s3 ls
  awslocal s3 ls s3://ecom-localstack-storage/invoices/
  ```
- Vérifier le rôle IAM :
  ```bash
  awslocal iam list-roles --query "Roles[?RoleName=='ecom-ec2-role']"
  ```

---

## 5. Intégration Applicative : Le Stockage S3 & Micro-Services

### Le pont Node.js vers AWS S3 :
- Nous avons intégré le SDK moderne modulaire **`@aws-sdk/client-s3`** dans le service `backend/src/services/s3Service.js`.
- **Résolution Docker transparente** :
  Dans un conteneur Docker, `localhost` désigne le conteneur lui-même. Notre service détecte automatiquement l'environnement Docker via `/.dockerenv` et redirige l'endpoint vers `http://host.docker.internal:4566` afin de joindre LocalStack sur la machine hôte sans friction.
- **Téléchargement sécurisé** :
  La route `GET /api/orders/:id/invoice` vérifie que l'utilisateur demandeur est bien le propriétaire de la commande ou un administrateur (vérification du token JWT), puis lit le flux S3 via `GetObjectCommand` et le transmet au client avec le bon header `Content-Type: application/pdf`.

---

## 6. Passage au Vrai Cloud AWS (Production) : Ce qui change

C'est **la question maîtresse** que le jury vous posera : *"Comment passe-t-on de votre maquette LocalStack à une vraie production sur AWS ?"*

Voici les changements précis à expliquer point par point :

### A. Ce qui change dans le code Terraform (`terraform/`)

1. **Suppression des Endpoints Locaux (`provider.tf`)** :
   Sur le vrai AWS, on retire le bloc `endpoints { ... }` qui pointait vers le port 4566. Terraform contacte directement les serveurs d'Amazon dans la région voulue (ex: `eu-west-3` pour Paris).
   ```hcl
   # Sur AWS réel :
   provider "aws" {
     region = "eu-west-3" # Région Paris
     # Plus besoin d'endpoints locaux ni de skip_credentials_validation
   }
   ```
2. **Gestion des Identifiants (Credentials)** :
   Au lieu des fausses clés `test`/`test`, on utilise :
   - En local : le profil AWS CLI configuré via `aws configure` ou `aws sso login`.
   - En CI/CD (GitHub Actions / GitLab CI) : l'authentification **OIDC (OpenID Connect)** sans aucune clé statique, via assomption de rôle IAM temporaire.
3. **Recherche Dynamique d'AMI (`ec2.tf`)** :
   Au lieu d'un ID d'AMI statique, on utilise un `data "aws_ami"` pour récupérer automatiquement la dernière image officielle certifiée Amazon Linux 2023 ou Ubuntu 24.04 LTS.
4. **Backend Terraform Distant (State)** :
   En local, le fichier `terraform.tfstate` est stocké sur disque. En équipe/production, on configure un backend distant sécurisé :
   - Un bucket S3 chiffré pour stocker le fichier d'état `terraform.tfstate`.
   - Une table DynamoDB pour verrouiller le state (`State Locking`) et éviter les conflits d'applications concurrentes.

---

### B. L'Architecture Cible Recommandée en Production sur AWS

En production réelle, on n'héberge pas tous ses conteneurs manuellement sur des machines EC2 brutes. On bascule sur des **services managés AWS** :

```
                        CLIENT INTERNET
                              │
                              ▼
                     Route 53 (DNS) + ACM (Certificat SSL)
                              │
                              ▼
                     CloudFront (CDN Caching)
                              │
                              ▼
                 Application Load Balancer (ALB)
                    (Subnets Publics Multi-AZ)
                              │
        ┌─────────────────────┴─────────────────────┐
        ▼                                           ▼
  AWS ECS Fargate                             AWS ECS Fargate
 (Frontend & Backend)                        (Frontend & Backend)
  AZ-a (Subnet Privé)                         AZ-b (Subnet Privé)
        │                                           │
        ├─────────────────────┬─────────────────────┤
        ▼                     ▼                     ▼
   Amazon S3              Amazon SQS          Amazon RDS PostgreSQL
(Factures & Assets)    (File de messages)      (Multi-AZ Managé)
                              │
                              ▼
                        ECS Worker Task
```

1. **Calcul & Conteneurs : AWS ECS Fargate** :
   - Remplacer les machines EC2 brutes par **AWS ECS (Elastic Container Service)** en mode **Fargate** (Serverless).
   - Plus de serveurs Linux à patcher, mettre à jour ou surveiller.
   - Les images Docker sont hébergées sur le registre privé **AWS ECR (Elastic Container Registry)**.
   - **Auto-scaling** automatique en fonction de la charge CPU/mémoire.
2. **Base de Données : Amazon RDS PostgreSQL** :
   - Remplacer le conteneur PostgreSQL par une instance managée **Amazon RDS**.
   - Avantages : Sauvegardes automatiques quotidiennes, réplication Multi-AZ (tolérance aux pannes), chiffrement au repos avec AWS KMS, mises à jour sans coupure.
3. **Répartition de Charge & Sécurité : Application Load Balancer (ALB)** :
   - Un ALB placé dans les sous-réseaux publics reçoit le trafic HTTPS sur le port 443.
   - Certificat SSL/TLS gratuit et auto-renouvelé via **AWS Certificate Manager (ACM)**.
   - Redirection sécurisée vers les conteneurs dans les sous-réseaux privés.
4. **Passerelle NAT (NAT Gateway)** :
   - Placée dans le sous-réseau public pour permettre aux conteneurs privés (ECS, Worker) d'accéder à Internet (ex: API externes, mises à jour) sans jamais être joignables directement depuis Internet.
5. **Découplage des Événements : Amazon SQS** :
   - Le worker scrute actuellement la base toutes les 5 secondes (polling).
   - En production, le backend publie un message dans une file **Amazon SQS** (`order-created`), et le worker consomme les messages en temps réel sans surcharger la base PostgreSQL.
6. **Envoi d'Emails : Amazon SES (Simple Email Service)** :
   - Remplacement du serveur SMTP classique par AWS SES pour garantir un taux de délivrabilité maximal et éviter le blacklistage d'IP.
7. **Observabilité & Logs : Amazon CloudWatch** :
   - Centralisation des logs applicatifs (Backend, Worker, Nginx) dans CloudWatch Logs avec dashboards et alarmes en cas d'erreurs 5xx.

---

## 7. Plan Type pour l'Oral (10-15 min)

| Durée | Section | Contenu Clé à aborder |
|---|---|---|
| **1-2 min** | **Introduction** | Contexte, problématique du passage au cloud, présentation succincte de la boutique e-commerce. |
| **3-4 min** | **L'Application & Micro-services** | Découpage Frontend / Backend / Worker / PDF-Service / BDD. Présentation du flux de commande. |
| **4-5 min** | **L'Infrastructure Terraform & LocalStack** | Démonstration du réseau (VPC, Subnets), Security Groups étanches, IAM Role pour S3, instances EC2. Démonstration des commandes `terraform apply` et `scripts/verify.sh` avec `awslocal`. |
| **2-3 min** | **Démonstration Fonctionnelle** | Passer une commande en direct, montrer la facture PDF générée dans le bucket S3 LocalStack (`awslocal s3 ls`), et son téléchargement depuis l'UI admin. |
| **3-4 min** | **Vision Production AWS** | Expliquer précisément la transition vers le vrai AWS (RDS, ECS Fargate, ALB, SQS, KMS, CI/CD). |
| **--** | **Questions / Réponses** | Clôture et échange avec le jury. |

---

## 8. Questions Pièges du Jury & Réponses Types

### Q1 : Pourquoi avoir utilisé LocalStack plutôt que de déployer directement sur un compte AWS réel ?
> **Réponse :**
> *"Pour des raisons de maîtrise des coûts, de rapidité et de sécurité. LocalStack permet de prototyper et tester l'intégralité du cycle Terraform en boucle courte sans débourser un centime ni risquer d'oublier des ressources allumées. Comme le code Terraform cible l'API standard AWS, la transition vers le cloud réel ne nécessite que de changer la cible du provider sans réécrire l'architecture."*

### Q2 : Pourquoi avoir créé deux sous-réseaux (Public et Privé) ?
> **Réponse :**
> *"C'est le principe fondamental de segmentation réseau et de défense en profondeur. Les composants exposés aux clients (Frontend, API) résident dans le sous-réseau public accessible via l'Internet Gateway. En revanche, la base de données PostgreSQL contient des données sensibles et ne doit sous aucun prétexte posséder d'IP publique. Elle est donc isolée dans le sous-réseau privé et accessible uniquement depuis le Security Group du Backend."*

### Q3 : Comment gérez-vous la sécurité des identifiants AWS dans votre application ?
> **Réponse :**
> *"Nous n'injectons aucune clé d'accès statique en dur dans le code source. Sur l'infrastructure, nous avons créé un rôle IAM (`ecom-ec2-role`) encapsulé dans un `Instance Profile` rattaché à l'EC2. L'instance récupère ainsi des identifiants temporaires automatiquement via le service de métadonnées AWS. En production sous ECS, nous utiliserions les `Task Roles` pour donner les droits S3 strictement au conteneur backend sans donner de droits au reste du système."*

### Q4 : Que feriez-vous de différent si le trafic passait de 10 à 10 000 utilisateurs simultanés ?
> **Réponse :**
> *"Je remplacerais immédiatement le conteneur EC2 unique par un cluster ECS Fargate avec politique d'auto-scaling horizontal derrière un Application Load Balancer. Je migrerais PostgreSQL vers Amazon RDS Multi-AZ avec Read Replicas pour décharger les requêtes de lecture du catalogue. Enfin, je placerais Amazon CloudFront (CDN) devant le bucket S3 et le frontend pour mettre en cache les images et assets statiques au plus près des utilisateurs."*

### Q5 : Pourquoi avoir séparé la génération de facture dans un micro-service dédié (`pdf-service`) ?
> **Réponse :**
> *"La manipulation de flux binaires et la génération de PDF via `pdfkit` sont des opérations synchrones gourmandes en CPU et mémoire. En isolant cette responsabilité dans un micro-service dédié, on protège l'API principale Node.js contre d'éventuels ralentissements de l'Event Loop lors de pics de commandes."*

