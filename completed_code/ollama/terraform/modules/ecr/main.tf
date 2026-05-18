# ============================================================
# ECR Module - Creates ECR repository for payment-api images
# ============================================================

# ECR repository for payment-api
resource "aws_ecr_repository" "payment_api" {
  name                 = var.repository_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "demo"
    Project     = "payment-api"
    ManagedBy   = "terraform"
  }
}

# ECR lifecycle policy - commented out due to schema validation issues
# Can be added later with proper tag patterns
# resource "aws_ecr_lifecycle_policy" "payment_api" {
#   repository = aws_ecr_repository.payment_api.name
#
#   policy = jsonencode({
#     rules = [
#       {
#         rulePriority = 1
#         description  = "Keep last 10 tagged images"
#         selection = {
#           tagStatus   = "tagged"
#           tagPrefixList = ["*"]
#           countType   = "imageCountMoreThan"
#           countNumber = 10
#         }
#         action = {
#           type = "expire"
#         }
#       }
#     ]
#   })
#
#   depends_on = [aws_ecr_repository.payment_api]
# }
