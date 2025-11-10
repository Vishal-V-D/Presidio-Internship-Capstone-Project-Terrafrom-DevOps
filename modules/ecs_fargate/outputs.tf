output "cluster_id" {
  description = "Quantum Judge ECS Cluster ID"
  value       = aws_ecs_cluster.quantum_judge.id
}

output "cluster_name" {
  description = "Quantum Judge ECS Cluster Name"
  value       = aws_ecs_cluster.quantum_judge.name
}

output "cluster_arn" {
  description = "Quantum Judge ECS Cluster ARN"
  value       = aws_ecs_cluster.quantum_judge.arn
}

output "service_name" {
  description = "Quantum Judge ECS Service Name"
  value       = aws_ecs_service.quantum_judge.name
}

output "service_id" {
  description = "Quantum Judge ECS Service ID"
  value       = aws_ecs_service.quantum_judge.id
}

output "task_definition_arn" {
  description = "Quantum Judge Task Definition ARN"
  value       = aws_ecs_task_definition.quantum_judge.arn
}

output "security_group_id" {
  description = "ECS Security Group ID"
  value       = aws_security_group.ecs_sg.id
}
