output "db_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.main.id
}

output "db_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.main.endpoint
}

output "db_address" {
  description = "RDS host address"
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "RDS port"
  value       = aws_db_instance.main.port
}

output "db_username" {
  description = "Master username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "secret_name" {
  description = "Secret name in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "secret_arn" {
  description = "Secret ARN in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "security_group_id" {
  description = "Security group ID for RDS"
  value       = aws_security_group.rds.id
}

output "databases_connection_info" {
  description = "Connection info for all databases inside the RDS instance"
  value = {
    quantum_judge = {
      host        = aws_db_instance.main.address
      port        = aws_db_instance.main.port
      database    = "quantum_judge"
      username    = aws_db_instance.main.username
      secret_name = aws_secretsmanager_secret.db_credentials.name
      description = "User contest service database"
    }
    submission_db = {
      host        = aws_db_instance.main.address
      port        = aws_db_instance.main.port
      database    = "submission_db"
      username    = aws_db_instance.main.username
      secret_name = aws_secretsmanager_secret.db_credentials.name
      description = "Submission service database"
    }
  }
  sensitive = true
}

output "database_names" {
  description = "Names of databases in the RDS instance"
  value = [
    "quantum_judge",
    "submission_db"
  ]
}
