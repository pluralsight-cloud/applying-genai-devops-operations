variable "aws_region" {
  description = "AWS region for the demo environment"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "demo-eks-cluster"
}

variable "cluster_admin_principal_arns" {
  description = "List of additional ARNs to grant cluster admin access"
  type        = list(string)
  default     = []
}

variable "eks_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.35"
}

variable "node_instance_type" {
  description = "EC2 instance type for the EKS managed node group"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_count" {
  description = "Desired number of nodes in the managed node group"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of nodes in the managed node group"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes in the managed node group"
  type        = number
  default     = 3
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository for the payment-api"
  type        = string
  default     = "payment-api"
}
