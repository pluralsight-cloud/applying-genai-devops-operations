# ============================================================
# EKS Access Entries - Grant cluster admin access
# Explicit access entries are more reliable than bootstrap_cluster_creator_admin_permissions
# ============================================================

# Access entry for the current Terraform user
resource "aws_eks_access_entry" "terraform_user" {
  cluster_name = module.eks.cluster_name
  principal_arn = data.aws_caller_identity.current.arn
  type         = "STANDARD"

  tags = {
    Environment = "demo"
    Project     = "payment-api"
    ManagedBy   = "terraform"
  }
}

# Access entries for additional admin principals
resource "aws_eks_access_entry" "additional_admins" {
  for_each = { for idx, arn in var.cluster_admin_principal_arns : idx => arn }

  cluster_name = module.eks.cluster_name
  principal_arn = each.value
  type         = "STANDARD"

  tags = {
    Environment = "demo"
    Project     = "payment-api"
    ManagedBy   = "terraform"
  }
}

# Policy association for Terraform user - grant cluster admin
resource "aws_eks_access_policy_association" "terraform_user_admin" {
  cluster_name  = module.eks.cluster_name
  access_scope {
    type = "cluster"
  }
  principal_arn = data.aws_caller_identity.current.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  depends_on = [aws_eks_access_entry.terraform_user]
}

# Policy associations for additional admin principals
resource "aws_eks_access_policy_association" "additional_admins_admin" {
  for_each = { for idx, arn in var.cluster_admin_principal_arns : idx => arn }

  cluster_name = module.eks.cluster_name
  access_scope {
    type = "cluster"
  }
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  depends_on = [aws_eks_access_entry.additional_admins]
}
