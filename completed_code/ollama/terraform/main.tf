# =============================================================================
# Root module - wires together VPC, EKS, and ECR modules
# =============================================================================

# VPC module - provides networking for the EKS cluster
module "vpc" {
  source = "./modules/vpc"

  name                = "demo-eks-vpc"
  vpc_cidr            = "10.0.0.0/16"
  aws_region          = var.aws_region
  azs                 = ["${var.aws_region}a", "${var.aws_region}b"]
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
}

# EKS module - creates the cluster, node group, add-ons, and OIDC provider
module "eks" {
  source = "./modules/eks"

  cluster_name            = var.cluster_name
  cluster_version         = var.eks_version
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  public_subnet_ids       = module.vpc.public_subnet_ids
  node_instance_type      = var.node_instance_type
  node_desired_count      = var.node_desired_count
  node_min_size           = var.node_min_size
  node_max_size           = var.node_max_size
  cluster_admin_principal_arns = var.cluster_admin_principal_arns
}

# ECR module - creates the repository for payment-api images
module "ecr" {
  source = "./modules/ecr"

  repository_name = var.ecr_repository_name
}
