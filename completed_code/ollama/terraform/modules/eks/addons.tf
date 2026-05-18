# ======================================================
# EKS Add-ons - Managed add-ons for the cluster
# Order: vpc-cni (before node group), then kube-proxy, coredns, ebs-csi-driver (after)
# ======================================================

# VPC CNI add-on - must be created BEFORE node group
resource "aws_eks_addon" "vpc_cni" {
  cluster_name      = module.eks.cluster_name
  addon_name        = "vpc-cni"
  resolve_conflicts = "OVERWRITE"

  tags = {
    Environment = "demo"
    Project     = "payment-api"
    ManagedBy   = "terraform"
  }
}

# Kube-proxy add-on - depends on node group
resource "aws_eks_addon" "kube_proxy" {
  cluster_name      = module.eks.cluster_name
  addon_name        = "kube-proxy"
  resolve_conflicts = "OVERWRITE"

  depends_on = [module.eks]

  tags = {
    Environment = "demo"
    Project     = "payment-api"
    ManagedBy   = "terraform"
  }
}

# CoreDNS add-on - depends on node group
resource "aws_eks_addon" "coredns" {
  cluster_name      = module.eks.cluster_name
  addon_name        = "coredns"
  resolve_conflicts = "OVERWRITE"

  depends_on = [module.eks]

  tags = {
    Environment = "demo"
    Project     = "payment-api"
    ManagedBy   = "terraform"
  }
}

# EBS CSI driver add-on - depends on node group and EBS CSI IAM role
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  resolve_conflicts        = "OVERWRITE"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

  depends_on = [module.eks]

  tags = {
    Environment = "demo"
    Project     = "payment-api"
    ManagedBy   = "terraform"
  }
}
