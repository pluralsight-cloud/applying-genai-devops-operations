output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "The EKS cluster API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_ca_data" {
  description = "The EKS cluster certificate authority data"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_oidc_issuer_url" {
  description = "The OIDC issuer URL for the EKS cluster"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "The ARN of the IAM OIDC provider"
  value       = module.eks.oidc_provider_arn
}

output "ebs_csi_driver_role_arn" {
  description = "The ARN of the EBS CSI driver IAM role"
  value       = aws_iam_role.ebs_csi_driver.arn
}
