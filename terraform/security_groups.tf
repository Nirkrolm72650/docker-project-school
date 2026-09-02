# ==============================================================================
# SECURITY GROUPS (FRONTEND, BACKEND, DATABASE)
# ==============================================================================

# 1. Security Group pour le Frontend (Accès public HTTP/HTTPS et SSH)
resource "aws_security_group" "frontend_sg" {
  name        = "ecom-frontend-sg"
  description = "Controle les acces entrants vers l'interface utilisateur web"
  vpc_id      = aws_vpc.main.id

  # Port HTTP par défaut (80)
  ingress {
    description = "HTTP standard"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Port Frontend Nginx alternatif (8080)
  ingress {
    description = "HTTP Frontend App"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Port SSH pour administration (22)
  ingress {
    description = "SSH Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress : Autorise tout le trafic sortant
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "ecom-frontend-sg"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# 2. Security Group pour le Backend API
resource "aws_security_group" "backend_sg" {
  name        = "ecom-backend-sg"
  description = "Controle les acces vers l'API REST Node.js"
  vpc_id      = aws_vpc.main.id

  # Port API Express (3000)
  ingress {
    description     = "API REST Node.js depuis Frontend SG"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }

  # Port API Express accessible pour les clients directs (optionnel / dev)
  ingress {
    description = "API REST Node.js direct access"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr, "0.0.0.0/0"]
  }

  # Port SSH
  ingress {
    description = "SSH Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "ecom-backend-sg"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# 3. Security Group pour PostgreSQL Database (Strictement isolé)
resource "aws_security_group" "db_sg" {
  name        = "ecom-db-sg"
  description = "Controle les acces vers la base de donnees PostgreSQL"
  vpc_id      = aws_vpc.main.id

  # Port PostgreSQL (5432) autorisé uniquement depuis le Security Group du Backend
  ingress {
    description     = "PostgreSQL depuis Backend API"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "ecom-db-sg"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

