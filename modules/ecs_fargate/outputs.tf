output "cluster_id" {
  value = aws_ecs_cluster.this.id
}

output "sg_id" {
  value = aws_security_group.ecs_sg.id
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.this.arn
}

output "service_name" {
  value = aws_ecs_service.this.name
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}
