# PREUVES — Validation de l'Infrastructure Cloud (`ecom`)

Ce document regroupe les sorties brutes d'exécution des 4 commandes de vérification de l'Étape 6, attestant du bon provisionnement de l'infrastructure sur LocalStack via `tflocal`.

---

## 1. Les machines existent et tournent

```bash
awslocal ec2 describe-instances \
  --filters "Name=tag:Project,Values=ecom" \
  --query 'Reservations[].Instances[].{Nom:Tags[?Key==`Name`]|[0].Value,Etat:State.Name,Type:InstanceType}' \
  --output table
```

**Sortie obtenue :**

```text
---------------------------------------------
|             DescribeInstances             |
+---------+--------------------+------------+
|  Etat   |        Nom         |   Type     |
+---------+--------------------+------------+
|  running|  ecom-postgres     |  t3.micro  |
|  running|  ecom-worker       |  t3.micro  |
|  running|  ecom-pdf-service  |  t3.micro  |
|  running|  ecom-frontend     |  t3.micro  |
|  running|  ecom-backend      |  t3.micro  |
+---------+--------------------+------------+
```

> ✅ **Validation :** Les 5 instances associées aux services migrés existent et sont toutes à l'état `running`.

---

## 2. Le pare-feu distingue bien public et interne

```bash
awslocal ec2 describe-security-groups \
  --filters "Name=group-name,Values=ecom-sg" \
  --query 'SecurityGroups[0].IpPermissions[].{Port:FromPort,Public:IpRanges[0].CidrIp,Interne:UserIdGroupPairs[0].GroupId}' \
  --output table
```

**Sortie obtenue :**

```text
-----------------------------------------------
|           DescribeSecurityGroups            |
+-----------------------+-------+-------------+
|        Interne        | Port  |   Public    |
+-----------------------+-------+-------------+
|  None                 |  8080 |  0.0.0.0/0  |
|  None                 |  3000 |  0.0.0.0/0  |
|  sg-bfe88c04ca168f13e |  5432 |  None       |
|  sg-bfe88c04ca168f13e |  4000 |  None       |
+-----------------------+-------+-------------+
```

> ✅ **Validation :** 
> - La colonne `Public` (`0.0.0.0/0`) est remplie **uniquement** pour les ports exposés sur Internet (Frontend `8080` et API Backend `3000`).
> - La colonne `Interne` (`self = true`, ID `sg-bfe88c04ca168f13e`) isole strictement la base de données PostgreSQL (`5432`) et le micro-service PDF (`4000`).

---

## 3. Le stockage et le disque existent

```bash
awslocal s3 ls
awslocal ec2 describe-volumes \
  --query 'Volumes[].{Id:VolumeId,Taille:Size,Attache:Attachments[0].InstanceId}' \
  --output table
```

**Sortie obtenue :**

```text
2026-09-03 15:13:45 ecom-invoices
```

```text
------------------------------------------------------------
|                      DescribeVolumes                     |
+----------------------+-------------------------+---------+
|        Attache       |           Id            | Taille  |
+----------------------+-------------------------+---------+
|  i-818a4059a4d33863a |  vol-c0b2d45faee18276d  |  10     |
|  i-818a4059a4d33863a |  vol-44826d4f46af65bba  |  8      |
|  i-6a1836333ccb608bb |  vol-ac97f625fc193aa2b  |  8      |
|  i-d51d479e8c413e5ca |  vol-869a64820a6b277e1  |  8      |
|  i-5b7a02caf1de65ea8 |  vol-deea006902d9ba646  |  8      |
|  i-e2ebf280458272fda |  vol-361f751904a19464f  |  8      |
+----------------------+-------------------------+---------+
```

> ✅ **Validation :**
> - Le bucket S3 `ecom-invoices` est bien présent.
> - Le volume EBS dédié `vol-c0b2d45faee18276d` (10 Go correspondant au volume nommé `pgdata`) est bien attaché à l'instance PostgreSQL (`i-818a4059a4d33863a`).

---

## 4. L'état Terraform reflète tout

```bash
tflocal state list
tflocal output
```

**Sortie obtenue :**

```text
aws_ebs_volume.pgdata
aws_iam_instance_profile.app
aws_iam_role.app
aws_iam_role_policy.app
aws_instance.backend
aws_instance.frontend
aws_instance.pdf_service
aws_instance.postgres
aws_instance.worker
aws_s3_bucket.invoices
aws_security_group.app
aws_volume_attachment.pgdata
module.reseau.aws_subnet.this
module.reseau.aws_vpc.this

backend_id = "i-e2ebf280458272fda"
frontend_id = "i-5b7a02caf1de65ea8"
pdf_service_id = "i-6a1836333ccb608bb"
postgres_id = "i-818a4059a4d33863a"
s3_bucket_name = "ecom-invoices"
subnet_id = "subnet-e45ace0f463585c99"
vpc_id = "vpc-336f2032b677b1297"
worker_id = "i-d51d479e8c413e5ca"
```

> ✅ **Validation :** L'intégralité des 14 ressources (VPC, Subnet, Security Group, S3, IAM Role/Policy/Profile, 5 instances, Volume EBS et Attachement) est enregistrée dans l'état Terraform avec les outputs correspondants.

