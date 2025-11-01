# ------------------------------------------------
# Global
# ------------------------------------------------
aws_region     = "us-east-1"
environment    = "dev"
cluster_name   = "smart-learning-dev"
service_name   = "smart-learning-backend-dev"

# ------------------------------------------------
# Networking
# ------------------------------------------------
vpc_id     = "vpc-0abc1234567890def"
subnet_ids = ["subnet-01abcd2345efgh678", "subnet-09ijkl0123mnop456"]

# ------------------------------------------------
# ECR and ECS
# ------------------------------------------------
ecr_url        = "071784445140.dkr.ecr.us-east-1.amazonaws.com/smart-learning-backend-dev"
rds_secret_arn = "arn:aws:secretsmanager:us-east-1:071784445140:secret:myapp-db-dev20251101113557721600000003-zoZSrj"

user_container_port   = 8080
course_container_port = 8081
desired_count         = 1
assign_public_ip      = true

# ------------------------------------------------
# Env vars for containers
# ------------------------------------------------
user_env_vars = [
  { name = "DB_HOST", value = "myapp-db-dev.capsi2agwav9.us-east-1.rds.amazonaws.com" },
  { name = "DB_USER", value = "admin" },
  { name = "DB_PORT", value = "3306" },
  { name = "PORT", value = "8080" },
  { name = "ENV", value = "dev" }
]

course_env_vars = [
  { name = "DB_HOST", value = "myapp-db-dev.capsi2agwav9.us-east-1.rds.amazonaws.com" },
  { name = "DB_USER", value = "admin" },
  { name = "DB_PORT", value = "3306" },
  { name = "PORT", value = "8081" },
  { name = "ENV", value = "dev" }
]

user_secret_vars = [
  {
    name      = "DB_PASSWORD"
    valueFrom = "arn:aws:secretsmanager:us-east-1:071784445140:secret:myapp-db-dev20251101113557721600000003-zoZSrj"
  }
]

course_secret_vars = [
  {
    name      = "DB_PASSWORD"
    valueFrom = "arn:aws:secretsmanager:us-east-1:071784445140:secret:myapp-db-dev20251101113557721600000003-zoZSrj"
  }
]

# ------------------------------------------------
# Tags
# ------------------------------------------------
tags = {
  Project     = "SmartLearning"
  Environment = "dev"
  Owner       = "Vishal"
  Scope       = "PPI"
}
