# ==============================================================================
# OUTPUTS TERRAFORM (INFRASTRUCTURE AWS / LOCALSTACK)
# ==============================================================================

# --- Networking ---
output "vpc_id" {
  description = "ID du VPC principal provisionne"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block du VPC"
  value       = aws_vpc.main.cidr_block
}

output "internet_gateway_id" {
  description = "ID de l'Internet Gateway rattache au VPC"
  value       = aws_internet_gateway.main.id
}

output "public_subnet_id" {
  description = "ID du sous-réseau public (Tier Web/App)"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID du sous-réseau privé (Tier Database)"
  value       = aws_subnet.private.id
}

# --- Security Groups ---
output "frontend_security_group_id" {
  description = "ID du Security Group Frontend"
  value       = aws_security_group.frontend_sg.id
}

output "backend_security_group_id" {
  description = "ID du Security Group Backend"
  value       = aws_security_group.backend_sg.id
}

output "database_security_group_id" {
  description = "ID du Security Group Database"
  value       = aws_security_group.db_sg.id
}

# --- IAM ---
output "iam_role_arn" {
  description = "ARN du rôle IAM pour EC2"
  value       = aws_iam_role.ec2_role.arn
}

output "iam_instance_profile_name" {
  description = "Nom de l'Instance Profile IAM rattaché à l'EC2"
  value       = aws_iam_instance_profile.ec2_profile.name
}

# --- S3 Storage ---
output "s3_bucket_name" {
  description = "Nom du bucket S3 provisionné pour les factures et assets"
  value       = aws_s3_bucket.app_bucket.id
}

output "s3_bucket_arn" {
  description = "ARN du bucket S3 applicatif"
  value       = aws_s3_bucket.app_bucket.arn
}

# --- Compute (EC2) ---
output "ec2_web_app_id" {
  description = "ID de l'instance EC2 Web & Application"
  value       = aws_instance.web_app.id
}

output "ec2_web_app_public_ip" {
  description = "Adresse IP publique de l'instance EC2 Web & Application"
  value       = aws_instance.web_app.public_ip
}

output "ec2_database_id" {
  description = "ID de l'instance EC2 Database"
  value       = aws_instance.database.id
}

output "ec2_database_private_ip" {
  description = "Adresse IP privée de l'instance EC2 Database"
  value       = aws_instance.database.private_ip
}

