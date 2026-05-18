# EKS cluster name
output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

# EKS cluster endpoint (API server URL)
output "cluster_endpoint" {
  description = "The EKS cluster API server endpoint"
  value       = module.eks.cluster_endpoint
}

# EKS cluster CA data for kubeconfig
output "cluster_ca_data" {
  description = "The EKS cluster certificate authority data for kubeconfig"
  value       = module.eks.cluster_ca_data
}

# update-kubeconfig helper command
output "kubeconfig_helper" {
  description = "Command to update kubeconfig for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# ECR repository URI for CI/CD pipeline
output "ecr_repository_uri" {
  description = "The ECR repository URI for the payment-api image pipeline"
  value       = module.ecr.repository_uri
}
