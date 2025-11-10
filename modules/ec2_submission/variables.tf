# ==================================================
# EC2 SUBMISSION SERVICE - VARIABLES
# ==================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EC2 will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium" # Recommended for DinD workloads
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "ecr_url" {
  description = "ECR repository URL"
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB"
  type        = string
  default     = null
}

variable "assign_public_ip" {
  description = "Assign public IP to EC2 instance"
  type        = bool
  default     = true
}

variable "enable_ssh_access" {
  description = "Enable SSH access to EC2"
  type        = bool
  default     = false
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = []
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  default     = 30
}

variable "user_data_replace_on_change" {
  description = "Replace instance when user data changes"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

# Database Configuration
variable "db_host" {
  description = "Database host"
  type        = string
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 3306
}

variable "db_user" {
  description = "Database user"
  type        = string
}

# Secret ARNs
variable "db_secret_arn" {
  description = "ARN of database password secret"
  type        = string
}

variable "jwt_secret_arn" {
  description = "ARN of JWT secret"
  type        = string
}

variable "jwt_secret_key" {
  description = "Key name for JWT secret in Secrets Manager"
  type        = string
  default     = "JWT_SECRET"
}

variable "genai_secret_arn" {
  description = "ARN of GenAI API key secret"
  type        = string
}

variable "genai_secret_key" {
  description = "Key name for GenAI secret in Secrets Manager"
  type        = string
  default     = "GENAI_API_KEY"
}

variable "secret_arns" {
  description = "List of all secret ARNs for IAM policy"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
