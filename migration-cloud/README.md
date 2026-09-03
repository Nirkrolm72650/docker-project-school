# Migration Cloud - Projet E-Commerce (`ecom`)

Ce dossier contient l'infrastructure cloud complète pour migrer l'application e-commerce multi-services sous LocalStack avec Terraform (`tflocal`).

## 🚀 Démarrage rapide

```bash
tflocal init      # Initialise le provider AWS et le module réseau
tflocal apply     # Déploie l'infrastructure (VPC, Subnet, Security Group, S3, IAM, 5 instances EC2, Volume EBS)
```

## 🧹 Nettoyage

```bash
tflocal destroy   # Détruit l'ensemble des ressources créées
```

## 📂 Contenu du rendu

- `INVENTAIRE.md` : Tableaux d'inventaire complet des services et justification des stratégies de migration.
- `main.tf` : Code d'infrastructure principal respectant les sections 4.1 à 4.8 du guide.
- `modules/reseau/` : Module réseau réutilisable (VPC et Subnet).
- `PREUVES.md` : Sorties des 4 commandes de vérification de l'Étape 6 prouvant le déploiement effectif.

