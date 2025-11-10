resource "aws_ecr_repository" "submission" {
  name                 = "submission-service-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Name        = "submission-service-${var.environment}"
    Project     = "QuantumJudge"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Service     = "submission-service"
  })
}

resource "aws_ecr_lifecycle_policy" "submission" {
  repository = aws_ecr_repository.submission.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only latest 5 submission-service images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["submission-service"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Expire untagged submission images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
