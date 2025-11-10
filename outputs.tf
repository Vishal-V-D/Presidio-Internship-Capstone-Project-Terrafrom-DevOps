# ================================================
# QUANTUM JUDGE - TERRAFORM OUTPUTS
# ================================================

# ------------------------------------------------
# Frontend (S3 + CloudFront)
# ------------------------------------------------
output "frontend_s3_website_url" {
  description = "Quantum Judge S3 website URL"
  value       = module.s3_cloudfront.s3_website_url
}

output "frontend_cloudfront_domain" {
  description = "Quantum Judge CloudFront distribution domain"
  value       = module.s3_cloudfront.cloudfront_domain
}

# ------------------------------------------------
# Database (RDS)
# ------------------------------------------------
output "database_endpoint" {
  description = "Quantum Judge RDS endpoint"
  value       = module.rds.db_endpoint
}

output "database_address" {
  description = "Quantum Judge RDS address (host only)"
  value       = module.rds.db_address
}

output "database_port" {
  description = "Quantum Judge RDS port"
  value       = module.rds.db_port
}

output "database_username" {
  description = "Quantum Judge RDS master username"
  value       = module.rds.db_username
  sensitive   = true
}

output "database_secret_arn" {
  description = "Quantum Judge RDS secret ARN in AWS Secrets Manager"
  value       = module.rds.secret_arn
}

output "database_security_group_id" {
  description = "Quantum Judge RDS security group ID"
  value       = module.rds.security_group_id
}

# ------------------------------------------------
# Container Registry (ECR)
# ------------------------------------------------
output "ecr_repository_url" {
  description = "Quantum Judge ECR repository URL (single repo for all services)"
  value       = module.ecr.repository_url
}

output "ecr_repository_name" {
  description = "Quantum Judge ECR repository name"
  value       = module.ecr.repository_name
}

output "ecr_repository_arn" {
  description = "Quantum Judge ECR repository ARN"
  value       = module.ecr.repository_arn
}

# ------------------------------------------------
# Container Service (ECS Fargate)
# ------------------------------------------------
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs.service_name
}

# Dedicated submission ECS service outputs
output "submission_ecs_cluster_name" {
  description = "Submission ECS cluster name"
  value       = var.use_ec2_for_submission ? null : module.ecs_submission[0].cluster_name
}

output "submission_ecs_service_name" {
  description = "Submission ECS service name"
  value       = var.use_ec2_for_submission ? null : module.ecs_submission[0].service_name
}

output "submission_ecs_task_definition_arn" {
  description = "Submission ECS task definition ARN"
  value       = var.use_ec2_for_submission ? null : module.ecs_submission[0].task_definition_arn
}

output "submission_ecs_security_group_id" {
  description = "Submission ECS security group ID"
  value       = var.use_ec2_for_submission ? null : module.ecs_submission[0].security_group_id
}

# EC2 Submission Service Outputs
output "submission_ec2_instance_id" {
  description = "ID of the submission service EC2 instance"
  value       = var.use_ec2_for_submission ? module.ec2_submission[0].instance_id : null
}

output "submission_ec2_public_ip" {
  description = "Public IP of the submission service EC2 instance"
  value       = var.use_ec2_for_submission ? module.ec2_submission[0].instance_public_ip : null
}

output "submission_ec2_private_ip" {
  description = "Private IP of the submission service EC2 instance"
  value       = var.use_ec2_for_submission ? module.ec2_submission[0].instance_private_ip : null
}

output "submission_service_url" {
  description = "Direct URL to submission service (EC2 or ALB)"
  value       = var.use_ec2_for_submission ? module.ec2_submission[0].submission_service_url : "http://${module.alb.alb_dns_name}:5000"
}

output "ecs_task_definition_arn" {
  description = "Quantum Judge ECS task definition ARN"
  value       = module.ecs.task_definition_arn
}

output "ecs_cluster_arn" {
  description = "Quantum Judge ECS cluster ARN"
  value       = module.ecs.cluster_arn
}

output "ecs_security_group_id" {
  description = "Quantum Judge ECS security group ID"
  value       = module.ecs.security_group_id
}

# ------------------------------------------------
# Application Load Balancer (ALB)
# ------------------------------------------------
output "alb_dns_name" {
  description = "Quantum Judge ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Quantum Judge ALB zone ID (for Route53)"
  value       = module.alb.alb_zone_id
}

output "alb_arn" {
  description = "Quantum Judge ALB ARN"
  value       = module.alb.alb_arn
}

# ------------------------------------------------
# Service URLs (Permanent - Use These!)
# ------------------------------------------------
output "user_contest_service_url" {
  description = "Permanent URL for User Contest Service"
  value       = module.alb.user_contest_url
}

output "rag_pipeline_service_url" {
  description = "Permanent URL for RAG Pipeline Service"
  value       = module.alb.rag_pipeline_url
}

output "alb_default_url" {
  description = "ALB default URL (service overview page)"
  value       = module.alb.alb_default_url
}

# ------------------------------------------------
# All Service URLs (Quick Reference)
# ------------------------------------------------
output "service_urls" {
  description = "All Quantum Judge service URLs"
  value = {
    overview         = module.alb.alb_default_url
    user_contest     = module.alb.user_contest_url
    submission       = module.alb.submission_url
    rag_pipeline     = module.alb.rag_pipeline_url
    frontend_s3      = module.s3_cloudfront.s3_website_url
    frontend_cdn     = "https://${module.s3_cloudfront.cloudfront_domain}"
  }
}
