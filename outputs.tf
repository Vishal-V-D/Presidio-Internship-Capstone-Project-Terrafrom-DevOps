
output "s3_website_url" {
  value = module.s3_cloudfront.s3_website_url
}

output "cloudfront_domain" {
  value = module.s3_cloudfront.cloudfront_domain
}


output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_endpoint
}

output "rds_address" {
  description = "RDS instance address (host only)"
  value       = module.rds.db_address
}

output "rds_port" {
  description = "RDS instance port"
  value       = module.rds.db_port
}

output "rds_username" {
  description = "Master username"
  value       = module.rds.db_username
  sensitive   = true
}

output "rds_secret_name" {
  description = "Secret name in AWS Secrets Manager"
  value       = module.rds.secret_name
}

output "rds_secret_arn" {
  description = "Secret ARN in AWS Secrets Manager"
  value       = module.rds.secret_arn
}

output "rds_security_group_id" {
  description = "Security group ID for RDS"
  value       = module.rds.security_group_id
}

output "databases_connection_info" {
  description = "Connection info for all databases inside the RDS instance"
  value       = module.rds.databases_connection_info
  sensitive   = true
}

output "ecr_url" {
  value = module.ecr_backend.repository_url
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}
