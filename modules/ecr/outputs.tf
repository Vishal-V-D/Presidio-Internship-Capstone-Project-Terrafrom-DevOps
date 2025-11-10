output "repository_url" {
  description = "Quantum Judge ECR Repository URL"
  value       = aws_ecr_repository.quantum_judge.repository_url
}

output "repository_arn" {
  description = "Quantum Judge ECR Repository ARN"
  value       = aws_ecr_repository.quantum_judge.arn
}

output "repository_name" {
  description = "Quantum Judge ECR Repository Name"
  value       = aws_ecr_repository.quantum_judge.name
}
