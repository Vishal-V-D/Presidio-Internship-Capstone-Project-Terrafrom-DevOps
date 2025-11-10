# ------------------------------------------------
# Core Configuration
# ------------------------------------------------
variable "cluster_name" {
  description = "ECS cluster name for Quantum Judge"
  type        = string
}

variable "service_name" {
  description = "ECS service name for Quantum Judge"
  type        = string
}

variable "ecr_url" {
  description = "ECR repository URL for all Quantum Judge images"
  type        = string
}

variable "aws_region" {
  description = "AWS region for CloudWatch logs"
  type        = string
  default     = "us-east-1"
}

# ------------------------------------------------
# Networking
# ------------------------------------------------
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

# ------------------------------------------------
# Task Configuration (Free Tier Optimized)
# ------------------------------------------------
variable "cpu" {
  description = "CPU units for task (256 = 0.25 vCPU - Free Tier)"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory for task in MB (512 MB - Free Tier)"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of task instances (1 for free tier)"
  type        = number
  default     = 1
}

# ------------------------------------------------
# IAM
# ------------------------------------------------
variable "rds_secret_arn" {
  description = "ARN of RDS secret in Secrets Manager"
  type        = string
}

# ------------------------------------------------
# User Contest Service (Port 4000)
# ------------------------------------------------
variable "user_contest_env_vars" {
  description = "Environment variables for user-contest-service"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "user_contest_secret_vars" {
  description = "Secret variables for user-contest-service"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

# ------------------------------------------------
# RAG Pipeline (Port 8000)
# ------------------------------------------------
variable "rag_pipeline_env_vars" {
  description = "Environment variables for rag-pipeline"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "rag_pipeline_secret_vars" {
  description = "Secret variables for rag-pipeline"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

# ------------------------------------------------
# ALB Integration (Optional)
# ------------------------------------------------
variable "alb_security_group_id" {
  description = "Security group ID of the ALB (optional - for restricting ECS access to ALB only)"
  type        = string
  default     = null
}

variable "user_contest_target_group_arn" {
  description = "Target group ARN for user-contest-service (optional - for ALB integration)"
  type        = string
  default     = null
}

variable "rag_pipeline_target_group_arn" {
  description = "Target group ARN for rag-pipeline (optional - for ALB integration)"
  type        = string
  default     = null
}

# ------------------------------------------------
# Tags
# ------------------------------------------------
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
