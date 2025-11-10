# ==================================================
# SUBMISSION SERVICE ECS (FARGATE) - VARIABLES
# ==================================================

variable "cluster_name" {
  description = "ECS cluster name for submission service"
  type        = string
}

variable "service_name" {
  description = "ECS service name for submission service"
  type        = string
}

variable "ecr_url" {
  description = "ECR repository URL for submission service image"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "subnet_ids" {
  description = "List of subnet IDs for ECS tasks"
  type        = list(string)
  default     = []
}

variable "vpc_id" {
  description = "VPC ID for security group"
  type        = string
}

variable "assign_public_ip" {
  description = "Assign public IP to ECS tasks"
  type        = bool
  default     = true
}

variable "cpu" {
  description = "CPU units for submission task"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory (MB) for submission task"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired task count"
  type        = number
  default     = 1
}

variable "rds_secret_arn" {
  description = "ARN of RDS secret"
  type        = string
}

variable "submission_env_vars" {
  description = "Environment variables for submission-service"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "submission_secret_vars" {
  description = "Secret variables for submission-service"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "alb_security_group_id" {
  description = "ALB security group ID"
  type        = string
  default     = null
}

variable "submission_target_group_arn" {
  description = "ALB target group ARN for submission service"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
