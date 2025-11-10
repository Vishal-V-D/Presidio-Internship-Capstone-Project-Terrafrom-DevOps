variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "alb_name" {
  description = "Name of the Application Load Balancer"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ALB will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ALB (must be in at least 2 AZs)"
  type        = list(string)
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false
}

variable "user_contest_health_path" {
  description = "Health check path for user contest service"
  type        = string
  default     = "/health"
}

variable "submission_health_path" {
  description = "Health check path for submission service"
  type        = string
  default     = "/health"
}

variable "rag_pipeline_health_path" {
  description = "Health check path for RAG pipeline"
  type        = string
  default     = "/health"
}

variable "submission_target_type" {
  description = "Target type for submission service target group (ip for ECS, instance for EC2)"
  type        = string
  default     = "ip"
  
  validation {
    condition     = contains(["ip", "instance"], var.submission_target_type)
    error_message = "Target type must be either 'ip' or 'instance'."
  }
}

variable "tags" {
  description = "Tags to apply to ALB resources"
  type        = map(string)
  default     = {}
}
