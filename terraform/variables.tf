variable "aws_region" {
  description = "Région AWS émulée par LocalStack"
  type        = string
  default     = "us-east-1"
}

variable "localstack_endpoint" {
  description = "Point de terminaison pour l'émulateur LocalStack"
  type        = string
  default     = "http://localhost:4566"
}

variable "environment" {
  description = "Environnement de déploiement (ex: dev, staging, prod)"
  type        = string
  default     = "development"
}

variable "vpc_cidr" {
  description = "Plage CIDR pour le VPC principal"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Plage CIDR pour le sous-réseau public (web/app)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Plage CIDR pour le sous-réseau privé (database)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "instance_type" {
  description = "Type d'instance EC2"
  type        = string
  default     = "t3.micro"
}

variable "s3_bucket_name" {
  description = "Nom unique du bucket S3 applicatif pour les factures et données"
  type        = string
  default     = "ecom-localstack-storage"
}

