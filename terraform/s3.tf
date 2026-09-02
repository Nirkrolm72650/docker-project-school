# ==============================================================================
# S3 BUCKET & STRUCTURE DE DOSSIERS POUR L'APPLICATION
# ==============================================================================

# Bucket principal S3 pour stocker les factures, images de produits et rapports
resource "aws_s3_bucket" "app_bucket" {
  bucket        = var.s3_bucket_name
  force_destroy = true

  tags = {
    Name        = var.s3_bucket_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Création du préfixe/dossier pour les factures de commandes
resource "aws_s3_object" "invoices_folder" {
  bucket       = aws_s3_bucket.app_bucket.id
  key          = "invoices/"
  content_type = "application/x-directory"
}

# Création du préfixe/dossier pour les médias et images produits
resource "aws_s3_object" "products_folder" {
  bucket       = aws_s3_bucket.app_bucket.id
  key          = "products/"
  content_type = "application/x-directory"
}

