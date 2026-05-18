output "repository_uri" {
  description = "The ECR repository URI"
  value       = aws_ecr_repository.payment_api.repository_url
}

output "repository_name" {
  description = "The ECR repository name"
  value       = aws_ecr_repository.payment_api.name
}
