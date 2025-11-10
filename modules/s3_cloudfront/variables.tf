variable "bucket_name" {
  description = "Name of the S3 bucket for Quantum Judge frontend"
  type        = string
}

variable "tags" {
  description = "Tags to apply to S3 and CloudFront resources"
  type        = map(string)
  default     = {}
}

# ------------------------------------------------
# Automatic Frontend Deployment (Optional)
# ------------------------------------------------
variable "frontend_source_dir" {
  description = "Path to frontend build directory (e.g., ./frontend/dist). Set to null to disable auto-deployment."
  type        = string
  default     = null
}

variable "force_deploy" {
  description = "Force frontend deployment even if files haven't changed. Set to true to trigger deployment."
  type        = bool
  default     = false
}
