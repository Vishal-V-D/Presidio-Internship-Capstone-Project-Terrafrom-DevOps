output "cluster_name" {
  description = "Submission service ECS cluster name"
  value       = aws_ecs_cluster.submission.name
}

output "service_name" {
  description = "Submission service ECS service name"
  value       = aws_ecs_service.submission.name
}

output "task_definition_arn" {
  description = "Submission service task definition ARN"
  value       = aws_ecs_task_definition.submission.arn
}

output "security_group_id" {
  description = "Submission service security group ID"
  value       = aws_security_group.submission_sg.id
}
