# ------------------------------------------------
# Global Configuration
# ------------------------------------------------
variable "aws_region" {
  description = "AWS region for Quantum Judge infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# ------------------------------------------------
# Frontend Deployment (Optional)
# ------------------------------------------------
variable "frontend_source_dir" {
  description = "Path to frontend build directory for auto-deployment. Set to enable automatic S3 upload and CloudFront invalidation."
  type        = string
  default     = null
  # Example: "./frontend/dist" or "D:/my-project/frontend/build"
}

variable "force_deploy" {
  description = "Force frontend deployment on every terraform apply"
  type        = bool
  default     = false
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
  description = "Secret variables for user-contest-service from Secrets Manager"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "db_secret_config" {
  description = "Configuration for the database credentials secret"
  type = object({
    secret_name = string
  })
  default = {
    secret_name = "quantum-judge-db"
  }
}

variable "jwt_secret_config" {
  description = "Configuration for the JWT secret"
  type = object({
    secret_name = string
    key         = string
    default     = string
  })
  default = {
    secret_name = "quantum-judge-jwt-secret"
    key         = "jwt_secret"
    default     = "change-me"
  }
}

# ------------------------------------------------
# Submission Service (Port 5000)
# ------------------------------------------------
variable "submission_env_vars" {
  description = "Environment variables for submission-service"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "submission_secret_vars" {
  description = "Secret variables for submission-service from Secrets Manager"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "genai_secret_config" {
  description = "Configuration for the GenAI API key secret"
  type = object({
    secret_name = string
    key         = string
    default     = string
  })
  default = {
    secret_name = "quantum-judge-genai-key"
    key         = "genai_api_key"
    default     = "change-me"
  }
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
  description = "Secret variables for rag-pipeline from Secrets Manager"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "gemini_secret_config" {
  description = "Configuration for the Gemini API key secret"
  type = object({
    secret_name = string
    key         = string
    default     = string
  })
  default = {
    secret_name = "quantum-judge-gemini-key"
    key         = "gemini_api_key"
    default     = "change-me"
  }
}

# ------------------------------------------------
# EC2 Submission Service (Docker-in-Docker)
# ------------------------------------------------
variable "use_ec2_for_submission" {
  description = "Use EC2 instead of ECS for submission service (required for Docker-in-Docker)"
  type        = bool
  default     = true
}

variable "submission_ec2_instance_type" {
  description = "EC2 instance type for submission service"
  type        = string
  default     = "t3.medium" # Recommended for DinD workloads
}

variable "enable_submission_ssh" {
  description = "Enable SSH access to submission service EC2 instance"
  type        = bool
  default     = false
}

variable "submission_ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access to submission service"
  type        = list(string)
  default     = []
}

variable "submission_ec2_key_name" {
  description = "EC2 key pair name for SSH access to submission service"
  type        = string
  default     = null
}
