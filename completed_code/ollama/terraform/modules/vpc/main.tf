# VPC module - creates the networking infrastructure for the EKS cluster
# Uses the official terraform-aws-modules/vpc/aws module (v5+)

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.name

  cidr                    = var.vpc_cidr
  azs                     = var.azs
  private_subnets         = var.private_subnet_cidrs
  public_subnets          = var.public_subnet_cidrs
  enable_dns_hostnames      = true
  enable_nat_gateway      = true
  single_nat_gateway      = true

  tags = {
    Environment = "demo"
    Project     = "payment-api"
    ManagedBy   = "terraform"
  }
}
