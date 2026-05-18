variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "demo-eks-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.35"
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the node group"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the cluster"
  type        = list(string)
}

variable "node_instance_type" {
  description = "EC2 instance type for the managed node group"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_count" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 3
}

variable "cluster_admin_principal_arns" {
  description = "Additional ARNs to grant cluster admin access"
  type        = list(string)
  default     = []
}
