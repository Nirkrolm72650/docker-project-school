# ==============================================================================
# INSTANCES EC2 (SERVEUR WEB / APP & SERVEUR DATABASE)
# ==============================================================================

# Clé SSH pour le déploiement et l'administration
resource "aws_key_pair" "deployer" {
  key_name   = "ecom-deployer-key"
  public_key = file("${path.module}/ecom_key.pub")

  tags = {
    Name        = "ecom-deployer-key"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# 1. Instance EC2 - Serveur Web & Application (Sous-réseau Public)
# Héberge le Frontend Nginx, le Backend REST Node.js et le Worker asynchrone
resource "aws_instance" "web_app" {
  ami                         = "ami-0c55b159cbfafe1f0" # AMI standard Linux émulée sous LocalStack
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.frontend_sg.id, aws_security_group.backend_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              set -e
              echo "=== Initialisation de l'instance Web & Application ==="
              echo "VPC: ${aws_vpc.main.id}"
              echo "S3 Bucket: ${aws_s3_bucket.app_bucket.id}"
              echo "Demarrage de l'environnement applicatif Docker..."
              docker compose up -d backend worker frontend
              echo "=== Deploiement termine avec succes ==="
              EOF

  tags = {
    Name        = "ecom-web-app"
    Role        = "Application"
    Tier        = "Public"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# 2. Instance EC2 - Base de Données (Sous-réseau Privé)
# Héberge l'instance PostgreSQL avec son stockage sécurisé
resource "aws_instance" "database" {
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  user_data = <<-EOF
              #!/bin/bash
              set -e
              echo "=== Initialisation de l'instance Database ==="
              echo "Lancement du conteneur PostgreSQL et injection du schema..."
              docker compose up -d postgres
              echo "=== Base de donnees prete ==="
              EOF

  tags = {
    Name        = "ecom-database"
    Role        = "Database"
    Tier        = "Private"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

