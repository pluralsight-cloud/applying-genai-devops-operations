# AWS provider configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "demo"
      Project     = "payment-api"
      ManagedBy   = "terraform"
    }
  }
}

# Data sources to get current AWS identity and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
