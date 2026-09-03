variable "project" {
  description = "Nom du projet pour le nommage et les tags"
  type        = string
}

variable "environment" {
  description = "Environnement de déploiement"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "Plage CIDR du VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "Plage CIDR du sous-réseau"
  type        = string
  default     = "10.0.1.0/24"
}
