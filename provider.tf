provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "BPS"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
