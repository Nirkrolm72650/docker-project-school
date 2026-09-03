# ==============================================================================
# 4.1 PROVIDER, VARIABLES, LOCALS
# ==============================================================================
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    ec2 = "http://localhost:4566"
    s3  = "http://localhost:4566"
    iam = "http://localhost:4566"
    sts = "http://localhost:4566"
  }
}

variable "project" {
  description = "Nom du projet pour les préfixes de ressources et le tag Project"
  type        = string
  default     = "ecom"
}

variable "environment" {
  description = "Environnement de déploiement"
  type        = string
  default     = "dev"
}

locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
  }
  ami_id = "ami-0abcdef1234567890" # identifiant fictif accepté par LocalStack
}

# ==============================================================================
# 4.2 LE STOCKAGE (S3)
# ==============================================================================
resource "aws_s3_bucket" "invoices" {
  bucket        = "${var.project}-invoices"
  force_destroy = true

  tags = merge(local.common_tags, { Name = "${var.project}-invoices" })
}

# ==============================================================================
# 4.3 LE RÉSEAU (MODULE VPC + SUBNET)
# ==============================================================================
module "reseau" {
  source      = "./modules/reseau"
  project     = var.project
  environment = var.environment
  vpc_cidr    = "10.0.0.0/16"
  subnet_cidr = "10.0.1.0/24"
}

# ==============================================================================
# 4.4 LE PARE-FEU (SECURITY GROUP UNIQUE APP)
# ==============================================================================
resource "aws_security_group" "app" {
  name        = "${var.project}-sg"
  description = "Controle des flux reseau de l'application e-commerce"
  vpc_id      = module.reseau.vpc_id

  # Modèle A — service PUBLIC : frontend (UI web consultée par utilisateurs)
  ingress {
    description = "frontend (interface web publique)"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Modèle A — service PUBLIC : backend (API REST consommée par clients et frontend)
  ingress {
    description = "backend (API REST publique)"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Modèle B — service INTERNE : pdf-service (interne uniquement)
  ingress {
    description = "pdf-service (interne uniquement)"
    from_port   = 4000
    to_port     = 4000
    protocol    = "tcp"
    self        = true
  }

  # Modèle B — service INTERNE : postgres (interne uniquement)
  ingress {
    description = "postgres (interne uniquement)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    self        = true
  }

  # Trafic sortant illimité
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project}-sg" })
}

# ==============================================================================
# 4.5 LE RÔLE IAM (POUR ACCÈS S3 DU BACKEND)
# ==============================================================================
resource "aws_iam_role" "app" {
  name = "${var.project}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, { Name = "${var.project}-role" })
}

resource "aws_iam_role_policy" "app" {
  name = "${var.project}-s3-policy"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.invoices.arn,
          "${aws_s3_bucket.invoices.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.project}-instance-profile"
  role = aws_iam_role.app.name

  tags = merge(local.common_tags, { Name = "${var.project}-instance-profile" })
}

# ==============================================================================
# 4.6 LES INSTANCES EC2 (UN BLOC PAR SERVICE NON 'RETIRE')
# ==============================================================================
# 1. Instance Frontend
resource "aws_instance" "frontend" {
  ami                    = local.ami_id
  instance_type          = "t3.micro"
  subnet_id              = module.reseau.subnet_id
  vpc_security_group_ids = [aws_security_group.app.id]

  tags = merge(local.common_tags, { Name = "${var.project}-frontend" })
}

# 2. Instance Backend (avec profil IAM pour S3)
resource "aws_instance" "backend" {
  ami                    = local.ami_id
  instance_type          = "t3.micro"
  subnet_id              = module.reseau.subnet_id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.app.name

  tags = merge(local.common_tags, { Name = "${var.project}-backend" })
}

# 3. Instance PDF Service
resource "aws_instance" "pdf_service" {
  ami                    = local.ami_id
  instance_type          = "t3.micro"
  subnet_id              = module.reseau.subnet_id
  vpc_security_group_ids = [aws_security_group.app.id]

  tags = merge(local.common_tags, { Name = "${var.project}-pdf-service" })
}

# 4. Instance Postgres
resource "aws_instance" "postgres" {
  ami                    = local.ami_id
  instance_type          = "t3.micro"
  subnet_id              = module.reseau.subnet_id
  vpc_security_group_ids = [aws_security_group.app.id]

  tags = merge(local.common_tags, { Name = "${var.project}-postgres" })
}

# 5. Instance Worker
resource "aws_instance" "worker" {
  ami                    = local.ami_id
  instance_type          = "t3.micro"
  subnet_id              = module.reseau.subnet_id
  vpc_security_group_ids = [aws_security_group.app.id]

  tags = merge(local.common_tags, { Name = "${var.project}-worker" })
}

# ==============================================================================
# 4.7 LES DISQUES EBS (UN COUPLE PAR VOLUME NOMMÉ : PGDATA)
# ==============================================================================
resource "aws_ebs_volume" "pgdata" {
  availability_zone = "us-east-1a"
  size              = 10

  tags = merge(local.common_tags, { Name = "${var.project}-pgdata" })
}

resource "aws_volume_attachment" "pgdata" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.pgdata.id
  instance_id = aws_instance.postgres.id
}

# ==============================================================================
# 4.8 LES OUTPUTS (UN PAR INSTANCE AU MINIMUM)
# ==============================================================================
output "frontend_id" {
  description = "ID de l'instance Frontend"
  value       = aws_instance.frontend.id
}

output "backend_id" {
  description = "ID de l'instance Backend"
  value       = aws_instance.backend.id
}

output "pdf_service_id" {
  description = "ID de l'instance PDF Service"
  value       = aws_instance.pdf_service.id
}

output "postgres_id" {
  description = "ID de l'instance PostgreSQL"
  value       = aws_instance.postgres.id
}

output "worker_id" {
  description = "ID de l'instance Worker"
  value       = aws_instance.worker.id
}

output "s3_bucket_name" {
  description = "Nom du bucket S3 créé"
  value       = aws_s3_bucket.invoices.bucket
}

output "vpc_id" {
  description = "ID du VPC créé via le module réseau"
  value       = module.reseau.vpc_id
}

output "subnet_id" {
  description = "ID du subnet créé via le module réseau"
  value       = module.reseau.subnet_id
}
