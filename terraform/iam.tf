# ==============================================================================
# IAM ROLES, POLICIES & INSTANCE PROFILES POUR EC2 ET S3
# ==============================================================================

# 1. Rôle IAM pour les instances EC2
resource "aws_iam_role" "ec2_role" {
  name        = "ecom-ec2-role"
  description = "Role IAM attribue aux instances EC2 de la plateforme e-commerce"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "ecom-ec2-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# 2. Politique IAM pour autoriser l'accès au bucket S3 applicatif
resource "aws_iam_policy" "s3_policy" {
  name        = "ecom-s3-access-policy"
  description = "Autorise les instances EC2 a lire et ecrire dans le bucket S3 ecom"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBucketContents"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.app_bucket.arn
        ]
      },
      {
        Sid    = "ReadWriteObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.app_bucket.arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name        = "ecom-s3-policy"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# 3. Attachement de la stratégie S3 au rôle EC2
resource "aws_iam_role_policy_attachment" "s3_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

# 4. Instance Profile pour attacher le rôle aux instances EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ecom-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name        = "ecom-ec2-instance-profile"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

