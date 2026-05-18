# ============================================================
# IAM OIDC Provider for IRSA (IAM Roles for Service Accounts)
# Required for EKS add-ons like aws-ebs-csi-driver
# Note: The EKS module already creates the OIDC provider, so we only need to fetch the certificate
# ============================================================

# Fetch the EKS cluster OIDC issuer certificate
data "tls_certificate" "eks_oidc" {
  url = module.eks.cluster_oidc_issuer_url
}

# Reference the OIDC provider created by the EKS module
# (No need to create a duplicate - the EKS module handles this)

# IAM role for EBS CSI driver (separate from application IRSA roles)
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.cluster_name}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })

  tags = {
    Environment = "demo"
    Project     = "payment-api"
    ManagedBy   = "terraform"
  }
}

# Attach the EBS CSI driver managed policy
resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
