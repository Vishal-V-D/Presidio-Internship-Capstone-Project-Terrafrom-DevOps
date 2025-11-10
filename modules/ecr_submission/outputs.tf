output "repository_url" {
  description = "Submission Service ECR Repository URL"
  value       = aws_ecr_repository.submission.repository_url
}

output "repository_arn" {
  description = "Submission Service ECR Repository ARN"
  value       = aws_ecr_repository.submission.arn
}

output "repository_name" {
  description = "Submission Service ECR Repository Name"
  value       = aws_ecr_repository.submission.name
}
