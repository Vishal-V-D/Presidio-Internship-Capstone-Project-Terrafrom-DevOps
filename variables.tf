variable "aws_region" {
  description = "AWS region for infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "user_secret_vars" {
  type = list(object({
    name      = string
    valueFrom = string
  }))
}

variable "course_secret_vars" {
  type = list(object({
    name      = string
    valueFrom = string
  }))
}



variable "user_db_secret_arn" {
  type = string
  default = null
}

variable "course_db_secret_arn" {
  type = string
  default = null
}

variable "rds_secret_arn" {
  type = string
}
