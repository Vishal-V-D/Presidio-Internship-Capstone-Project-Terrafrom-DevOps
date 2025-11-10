# ================================================
# QUANTUM JUDGE - TERRAFORM CONFIGURATION
# ================================================
# Professional naming standards applied throughout
# Single ECR repo with 3 image tags
# Single Fargate task with 3 containers
# Single RDS with 2 databases (quantum_judge, submission_db)
# Free tier optimized configuration
# ================================================

# ------------------------------------------------
# Global Configuration
# ------------------------------------------------
aws_region  = "us-east-1"
environment = "dev"

# ------------------------------------------------
# User Contest Service (Port 4000)
# ------------------------------------------------
# Database: quantum_judge
user_contest_env_vars = [
  { name = "PORT", value = "4000" },
  { name = "NODE_ENV", value = "production" },
  { name = "SERVICE_NAME", value = "user-contest-service" },
  
  # JWT Configuration
  { name = "JWT_EXPIRES_IN", value = "3h" }
]

user_contest_secret_vars = [
  # Additional secrets (if any) will be merged automatically; leave empty.
]

# ------------------------------------------------
# Submission Service (Port 5000)
# ------------------------------------------------
# Database: submission_db
submission_env_vars = [
  { name = "PORT", value = "5000" },
  { name = "NODE_ENV", value = "development" },
  { name = "SERVICE_NAME", value = "submission-service" },
  
  # Inter-service Communication (localhost works in same task)
  { name = "USER_CONTEST_SERVICE_URL", value = "http://localhost:4000" },
  
  # GenAI Configuration
  { name = "GENAI_API_URL", value = "http://localhost:8000/api/ai/feedback" },
  
  # JWT Configuration
  { name = "JWT_EXPIRES_IN", value = "3h" }
]

submission_secret_vars = [
  # Additional secrets (if any) will be merged automatically; leave empty.
]

# ------------------------------------------------
# RAG Pipeline Service (Port 8000)
# ------------------------------------------------
rag_pipeline_env_vars = [
  { name = "PORT", value = "8000" },
  { name = "NODE_ENV", value = "development" },
  { name = "SERVICE_NAME", value = "rag-pipeline" },
  
  # Gemini AI Configuration
  { name = "GEMINI_API_URL", value = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" },
  
  # Vector Store Configuration
  { name = "VECTORSTORE_DIR", value = "embeddings" }
]

rag_pipeline_secret_vars = [
  # Additional secrets (if any) will be merged automatically; leave empty.
]

# ------------------------------------------------
# EC2 Submission Service (Docker-in-Docker)
# ------------------------------------------------
# Use EC2 for Docker-in-Docker support (required for code execution)
use_ec2_for_submission = true

# Instance type - t3.micro for FREE TIER testing
submission_ec2_instance_type = "t3.micro"  # FREE (750h/month for 12 months)
# Note: t3.micro has 1GB RAM - good for testing, may be slow under load
# Upgrade to t3.small ($15/month) or t3.medium ($30/month) for production

# SSH Access (disabled for security)
enable_submission_ssh = false
# submission_ssh_cidr_blocks = ["YOUR_IP/32"]  # Uncomment to enable SSH
# submission_ec2_key_name = "your-key-pair"     # Uncomment to enable SSH
