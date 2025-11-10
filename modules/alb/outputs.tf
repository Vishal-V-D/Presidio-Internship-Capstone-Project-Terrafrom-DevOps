output "alb_id" {
  description = "ID of the Application Load Balancer"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "alb_security_group_id" {
  description = "Security group ID of the ALB"
  value       = aws_security_group.alb.id
}

# Target Group ARNs (for ECS service)
output "user_contest_target_group_arn" {
  description = "ARN of user contest service target group"
  value       = aws_lb_target_group.user_contest.arn
}

output "submission_target_group_arn" {
  description = "ARN of submission service target group"
  value       = aws_lb_target_group.submission.arn
}

output "rag_pipeline_target_group_arn" {
  description = "ARN of RAG pipeline target group"
  value       = aws_lb_target_group.rag_pipeline.arn
}

# Service URLs
output "user_contest_url" {
  description = "Permanent URL for User Contest Service"
  value       = "http://${aws_lb.main.dns_name}:4000"
}

output "submission_url" {
  description = "Permanent URL for Submission Service"
  value       = "http://${aws_lb.main.dns_name}:5000"
}

output "rag_pipeline_url" {
  description = "Permanent URL for RAG Pipeline"
  value       = "http://${aws_lb.main.dns_name}:8000"
}

output "alb_default_url" {
  description = "Default ALB URL (shows service overview)"
  value       = "http://${aws_lb.main.dns_name}"
}

# All service URLs combined
output "service_urls" {
  description = "All service permanent URLs"
  value = {
    user_contest = "http://${aws_lb.main.dns_name}:4000"
    submission   = "http://${aws_lb.main.dns_name}:5000"
    rag_pipeline = "http://${aws_lb.main.dns_name}:8000"
    default      = "http://${aws_lb.main.dns_name}"
  }
}
