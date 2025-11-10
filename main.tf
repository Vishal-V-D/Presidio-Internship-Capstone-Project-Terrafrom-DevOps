#-------------------------
# S3 + CLOUDFRONT MODULE
#-------------------------
module "s3_cloudfront" {
  source      = "./modules/s3_cloudfront"
  bucket_name = "quantum-judge-frontend-${var.environment}"

  # Automatic frontend deployment (optional)
  # Set frontend_source_dir to your build folder to enable auto-deployment
  # Example: frontend_source_dir = "./frontend/dist"
  frontend_source_dir = var.frontend_source_dir
  force_deploy        = var.force_deploy

  tags = {
    Name      = "quantum-judge-frontend-${var.environment}"
    Project   = "QuantumJudge"
    ManagedBy = "Terraform"
  }
}

#-------------------------
# FETCH DEFAULT VPC & SUBNETS
#-------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  
  # Exclude us-east-1e where t3.micro is not supported
  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]
  }
}

#-------------------------
# RDS MODULE (Free Tier)
#-------------------------
module "rds" {
  source = "./modules/rds"

  db_name                 = "quantum_judge_${var.environment}"
  db_username             = "admin"
  db_engine               = "mysql"
  db_engine_version       = "8.0.43"
  db_instance_class       = "db.t3.micro" # Free tier eligible
  allocated_storage       = 20            # Free tier: 20 GB
  multi_az                = false         # Single AZ for free tier
  backup_retention_period = 7
  publicly_accessible     = true
  skip_final_snapshot     = true

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  allowed_cidr_blocks = ["0.0.0.0/0"]

  aws_region = var.aws_region

  tags = {
    Name        = "quantum-judge-db-${var.environment}"
    Project     = "QuantumJudge"
    Service     = "shared-database"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

#-------------------------
# EC2 SUBMISSION SERVICE (Docker-in-Docker)
#-------------------------
# Use EC2 instead of ECS for submission service to support Docker-in-Docker
module "ec2_submission" {
  count  = var.use_ec2_for_submission ? 1 : 0
  source = "./modules/ec2_submission"

  name_prefix = "quantum-judge-${var.environment}"
  vpc_id      = data.aws_vpc.default.id
  subnet_id   = data.aws_subnets.default.ids[0] # Use first available subnet
  
  instance_type   = var.submission_ec2_instance_type
  aws_region      = var.aws_region
  ecr_url         = module.ecr.repository_url
  assign_public_ip = true

  # ALB Integration
  alb_security_group_id = module.alb.alb_security_group_id

  # SSH Access (optional)
  enable_ssh_access = var.enable_submission_ssh
  ssh_cidr_blocks   = var.submission_ssh_cidr_blocks
  key_name          = var.submission_ec2_key_name

  # Database Configuration
  db_host = module.rds.db_address
  db_port = module.rds.db_port
  db_user = nonsensitive(module.rds.db_username)

  # Secrets Configuration
  db_secret_arn    = module.rds.secret_arn
  jwt_secret_arn   = aws_secretsmanager_secret.jwt.arn
  jwt_secret_key   = var.jwt_secret_config.key
  genai_secret_arn = aws_secretsmanager_secret.genai.arn
  genai_secret_key = var.genai_secret_config.key

  secret_arns = [
    module.rds.secret_arn,
    "${module.rds.secret_arn}:*",
    "${module.rds.secret_arn}-*",
    aws_secretsmanager_secret.jwt.arn,
    "${aws_secretsmanager_secret.jwt.arn}:*",
    "${aws_secretsmanager_secret.jwt.arn}-*",
    aws_secretsmanager_secret.genai.arn,
    "${aws_secretsmanager_secret.genai.arn}:*",
    "${aws_secretsmanager_secret.genai.arn}-*"
  ]

  tags = {
    Project     = "QuantumJudge"
    Service     = "submission-service"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Register EC2 instance with ALB Target Group
resource "aws_lb_target_group_attachment" "submission_ec2" {
  count            = var.use_ec2_for_submission ? 1 : 0
  target_group_arn = module.alb.submission_target_group_arn
  target_id        = module.ec2_submission[0].instance_id
  port             = 5000
}

#-------------------------
# ECR MODULE (Single Repo for All Services)
#-------------------------
module "ecr" {
  source      = "./modules/ecr"
  environment = var.environment

  tags = {
    Owner     = "Vishal"
    Project   = "QuantumJudge"
    ManagedBy = "Terraform"
  }
}

#-------------------------
# Submission Service ECR (Dedicated Repo)
#-------------------------
module "ecr_submission" {
  source      = "./modules/ecr_submission"
  environment = var.environment

  tags = {
    Owner     = "Vishal"
    Project   = "QuantumJudge"
    ManagedBy = "Terraform"
    Service   = "submission-service"
  }
}

#-------------------------
# ALB MODULE (Permanent URLs for All Services)
#-------------------------
module "alb" {
  source = "./modules/alb"

  name_prefix = "quantum-judge-${var.environment}"
  alb_name    = "quantum-judge-alb-${var.environment}"

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  # Health check paths
  user_contest_health_path = "/health"
  submission_health_path   = "/health"
  rag_pipeline_health_path = "/health"

  # Target type for submission service (instance for EC2, ip for ECS)
  submission_target_type = var.use_ec2_for_submission ? "instance" : "ip"

  enable_deletion_protection = false # Set to true in production

  tags = {
    Name        = "quantum-judge-alb-${var.environment}"
    Project     = "QuantumJudge"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_secretsmanager_secret" "jwt" {
  name = "${var.jwt_secret_config.secret_name}-${var.environment}"

  tags = {
    Project     = "QuantumJudge"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "jwt"
  }
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id     = aws_secretsmanager_secret.jwt.id
  secret_string = jsonencode({
    (var.jwt_secret_config.key) = var.jwt_secret_config.default
  })
}

resource "aws_secretsmanager_secret" "genai" {
  name = "${var.genai_secret_config.secret_name}-${var.environment}"

  tags = {
    Project     = "QuantumJudge"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "genai"
  }
}

resource "aws_secretsmanager_secret_version" "genai" {
  secret_id     = aws_secretsmanager_secret.genai.id
  secret_string = jsonencode({
    (var.genai_secret_config.key) = var.genai_secret_config.default
  })
}

resource "aws_secretsmanager_secret" "gemini" {
  name = "${var.gemini_secret_config.secret_name}-${var.environment}"

  tags = {
    Project     = "QuantumJudge"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "gemini"
  }
}

resource "aws_secretsmanager_secret_version" "gemini" {
  secret_id     = aws_secretsmanager_secret.gemini.id
  secret_string = jsonencode({
    (var.gemini_secret_config.key) = var.gemini_secret_config.default
  })
}

#-------------------------
# ECS FARGATE MODULE (Single Task, 3 Containers)
#-------------------------
locals {
  db_password_secret_arn = "${module.rds.secret_arn}:password::"
  jwt_secret_arn         = "${aws_secretsmanager_secret.jwt.arn}:${var.jwt_secret_config.key}::"
  genai_secret_arn       = "${aws_secretsmanager_secret.genai.arn}:${var.genai_secret_config.key}::"
  gemini_secret_arn      = "${aws_secretsmanager_secret.gemini.arn}:${var.gemini_secret_config.key}::"

  user_contest_env_overrides = {
    DB_HOST = module.rds.db_address
    DB_PORT = tostring(module.rds.db_port)
    DB_USER = nonsensitive(module.rds.db_username)
    DB_NAME = "quantum_judge"
  }

  user_contest_secret_overrides = {
    DB_PASS    = local.db_password_secret_arn
    JWT_SECRET = local.jwt_secret_arn
  }

  submission_env_overrides = {
    DB_HOST = module.rds.db_address
    DB_PORT = tostring(module.rds.db_port)
    DB_USER = nonsensitive(module.rds.db_username)
    DB_NAME = "submission_db"
    USER_CONTEST_SERVICE_URL = module.alb.user_contest_url
    GENAI_API_URL            = "${module.alb.rag_pipeline_url}/api/ai/feedback"
  }

  submission_secret_overrides = {
    DB_PASS       = local.db_password_secret_arn
    JWT_SECRET    = local.jwt_secret_arn
    GENAI_API_KEY = local.genai_secret_arn
  }

  rag_pipeline_secret_overrides = {
    GEMINI_API_KEY = local.gemini_secret_arn
  }

  user_contest_env_vars_resolved = concat(
    [for e in var.user_contest_env_vars : merge(e, {
      value = lookup(local.user_contest_env_overrides, e.name, e.value)
    })],
    [for name, value in local.user_contest_env_overrides : {
      name  = name
      value = value
    } if !contains([for e in var.user_contest_env_vars : e.name], name)]
  )

  user_contest_secret_vars_resolved = concat(
    [for s in var.user_contest_secret_vars : merge(s, {
      valueFrom = lookup(local.user_contest_secret_overrides, s.name, s.valueFrom)
    })],
    [for name, valueFrom in local.user_contest_secret_overrides : {
      name      = name
      valueFrom = valueFrom
    } if !contains([for s in var.user_contest_secret_vars : s.name], name)]
  )

  submission_env_vars_resolved = concat(
    [for e in var.submission_env_vars : merge(e, {
      value = lookup(local.submission_env_overrides, e.name, e.value)
    })],
    [for name, value in local.submission_env_overrides : {
      name  = name
      value = value
    } if !contains([for e in var.submission_env_vars : e.name], name)]
  )

  submission_secret_vars_resolved = concat(
    [for s in var.submission_secret_vars : merge(s, {
      valueFrom = lookup(local.submission_secret_overrides, s.name, s.valueFrom)
    })],
    [for name, valueFrom in local.submission_secret_overrides : {
      name      = name
      valueFrom = valueFrom
    } if !contains([for s in var.submission_secret_vars : s.name], name)]
  )

  rag_pipeline_secret_vars_resolved = concat(
    [for s in var.rag_pipeline_secret_vars : merge(s, {
      valueFrom = lookup(local.rag_pipeline_secret_overrides, s.name, s.valueFrom)
    })],
    [for name, valueFrom in local.rag_pipeline_secret_overrides : {
      name      = name
      valueFrom = valueFrom
    } if !contains([for s in var.rag_pipeline_secret_vars : s.name], name)]
  )

}

module "ecs" {
  source = "./modules/ecs_fargate"

  cluster_name = "quantum-judge-${var.environment}"
  service_name = "quantum-judge-service-${var.environment}"

  # AWS Region
  aws_region = var.aws_region

  # ECR URL (single repo with multiple image tags)
  ecr_url = module.ecr.repository_url

  # Networking
  vpc_id           = data.aws_vpc.default.id
  subnet_ids       = data.aws_subnets.default.ids
  assign_public_ip = true

  # Free Tier Configuration
  cpu           = 256 # 0.25 vCPU
  memory        = 512 # 512 MB
  desired_count = 1   # Single instance

  # RDS Secret ARN for least privilege IAM
  rds_secret_arn = module.rds.secret_arn

  # User Contest Service (Port 4000)
  user_contest_env_vars    = local.user_contest_env_vars_resolved
  user_contest_secret_vars = local.user_contest_secret_vars_resolved

  # RAG Pipeline (Port 8000)
  rag_pipeline_env_vars    = var.rag_pipeline_env_vars
  rag_pipeline_secret_vars = local.rag_pipeline_secret_vars_resolved

  # ALB Integration (for permanent URLs)
  alb_security_group_id          = module.alb.alb_security_group_id
  user_contest_target_group_arn  = module.alb.user_contest_target_group_arn
  rag_pipeline_target_group_arn  = module.alb.rag_pipeline_target_group_arn

  tags = {
    Project     = "QuantumJudge"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

#-------------------------
# Submission Service ECS (Dedicated Module)
#-------------------------
module "ecs_submission" {
  count  = var.use_ec2_for_submission ? 0 : 1
  source = "./modules/ecs_submission_fargate"

  cluster_name = "submission-service-${var.environment}"
  service_name = "submission-service-${var.environment}"

  aws_region = var.aws_region
  ecr_url    = module.ecr_submission.repository_url

  vpc_id           = data.aws_vpc.default.id
  subnet_ids       = data.aws_subnets.default.ids
  assign_public_ip = true

  cpu           = 256
  memory        = 512
  desired_count = 1

  rds_secret_arn = module.rds.secret_arn

  submission_env_vars    = local.submission_env_vars_resolved
  submission_secret_vars = local.submission_secret_vars_resolved

  alb_security_group_id     = module.alb.alb_security_group_id
  submission_target_group_arn = module.alb.submission_target_group_arn

  tags = {
    Project     = "QuantumJudge"
    Service     = "submission-service"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
