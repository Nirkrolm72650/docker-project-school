# Migration Cloud - Projet E-Commerce (`ecom`)

Ce dossier contient l'infrastructure cloud complète pour migrer l'application e-commerce multi-services sous LocalStack avec Terraform (`tflocal`).

---

## 🚀 Démarrage rapide

```bash
# 1. Déployer l'infrastructure Cloud avec Terraform
tflocal init
tflocal apply -auto-approve

# 2. Lancer l'application conteneurisée (depuis la racine du projet)
cd ..
docker compose up -d --build
```

L'application est disponible sur :
- **Boutique Web :** http://localhost:8080
- **Dashboard Admin :** http://localhost:8080/admin.html (`admin@test.com` / `admin123`)

---

## 🔄 Recommencer tout de zéro (Reset complet)

Pour faire table rase et reconstruire l'ensemble de l'infrastructure et de l'application :

### Étape 1 : Tout détruire et nettoyer
```bash
# 1. Détruire l'infrastructure Terraform
cd migration-cloud
tflocal destroy -auto-approve

# 2. Supprimer les conteneurs et les volumes applicatifs
cd ..
docker compose down -v

# 3. Redémarrer LocalStack pour vider son état
docker restart localstack-aws
```

### Étape 2 : Tout relancer proprement
```bash
# 1. Re-provisionner l'infrastructure Cloud
cd migration-cloud
tflocal init
tflocal apply -auto-approve

# 2. Relancer l'application
cd ..
docker compose up -d --build
```

---

## 🔍 Vérifications rapides

```bash
# Vérifier les 5 instances EC2 créées dans LocalStack
awslocal ec2 describe-instances --query 'Reservations[].Instances[].{Nom:Tags[?Key==`Name`]|[0].Value,Etat:State.Name}' --output table

# Vérifier la connexion du backend au bucket S3
curl http://localhost:3000/api/aws/status

# Lister les factures générées dans S3
awslocal s3 ls s3://ecom-invoices/invoices/
```

---

## 🧹 Nettoyage final

```bash
cd migration-cloud
tflocal destroy -auto-approve
cd ..
docker compose down -v
```

---

## 📂 Contenu du rendu

- `INVENTAIRE.md` : Tableaux d'inventaire complet des services et justification des stratégies de migration (Étape 1 & 2).
- `main.tf` : Modélisation complète de l'infrastructure selon la grille d'évaluation (Sections 4.1 à 4.8).
- `modules/reseau/` : Module réseau réutilisable (VPC et Subnet).
- `PREUVES.md` : Sorties réelles des 4 commandes de vérification de l'Étape 6.
