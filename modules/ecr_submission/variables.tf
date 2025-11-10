variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Extra tags for the submission-service ECR repository"
  type        = map(string)
  default     = {}
}
