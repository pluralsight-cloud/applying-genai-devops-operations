# ======================================================================
# EKS Module - Creates EKS cluster, node group, add-ons, and OIDC provider
# Uses terraform-aws-modules/eks/aws module (v20+)
# ======================================================================

# Data sources for AWS identity and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# EKS module - creates the cluster and managed node group
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access = true

  vpc_id                   = var.vpc_id
  subnet_ids               = var.private_subnet_ids

  # Managed node group configuration
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Node group settings (using eks_managed_node_groups for v20+)
  eks_managed_node_groups = {
    demo-node-group = {
      instance_types = [var.node_instance_type]
      capacity_type  = "ON_DEMAND"
      scaling_config = {
        desired_size = var.node_desired_count
        min_size     = var.node_min_size
        max_size     = var.node_max_size
      }

      # Amazon Linux 2023 required for EKS 1.33+
      ami_type = "AL2023_x86_64_STANDARD"

      # Nodes in private subnets without public IPs
      public_access_ip = false

      # Tags for the node group
      tags = {
        Environment = "demo"
        Project     = "payment-api"
        ManagedBy   = "terraform"
      }
    }
  }

  # Tags for all EKS resources
  tags = {
    Environment = "demo"
    Project     = "payment-api"
    ManagedBy   = "terraform"
  }
}
