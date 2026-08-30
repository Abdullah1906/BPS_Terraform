resource "random_password" "sql_sa" {
  length  = 24
  special = true
}

resource "aws_secretsmanager_secret" "sql_credentials" {
  name                    = "${var.project_name}/${var.environment}/sql/sa"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "sql_credentials" {
  secret_id = aws_secretsmanager_secret.sql_credentials.id

  secret_string = jsonencode({
    username = "sa"
    password = random_password.sql_sa.result
  })
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.project_name}-${var.environment}-artifacts-${data.aws_caller_identity.current.account_id}"

  force_destroy = false
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_caller_identity" "current" {}
