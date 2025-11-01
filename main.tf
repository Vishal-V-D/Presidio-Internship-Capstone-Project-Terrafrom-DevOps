#-------------------------
# S3 + CLOUDFRONT MODULE
#-------------------------
module "s3_cloudfront" {
  source      = "./modules/s3_cloudfront"
  bucket_name = "smart-learning-frontend-dev"

  tags = {
    Name  = "smart-learning-frontend-dev"
    scope = "PPI"
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
}

#-------------------------
# RDS MODULE
#-------------------------
module "rds" {
  source = "./modules/rds"

  db_name              = "myapp_db_dev"
  db_username          = "admin"
  db_engine            = "mysql"
  db_engine_version    = "8.0.43"
  db_instance_class    = "db.t3.micro"
  allocated_storage    = 20
  multi_az             = false
  backup_retention_period = 7
  publicly_accessible  = true
  skip_final_snapshot  = true

  vpc_id               = data.aws_vpc.default.id
  subnet_ids           = data.aws_subnets.default.ids

  allowed_cidr_blocks = ["0.0.0.0/0"]

  tags = {
    Name        = "myapp-db-dev"
    scope       = "PPI"
    Service     = "shared-database"
    Environment = "Development"
  }
}

#-------------------------
# ECR MODULE
#-------------------------
module "ecr_backend" {
  source      = "./modules/ecr"
  environment = var.environment

  tags = {
    owner = "team-ppi"
  }
}


#-------------------------
# ECS FARGATE MODULE
#-------------------------
module "ecs" {
  source = "./modules/ecs_fargate"

  cluster_name = "smart-learning-dev"
  service_name = "smart-learning-backend-dev"

  # ECR URL
  ecr_url = module.ecr_backend.repository_url

  # USE DEFAULT VPC + SUBNETS
  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  user_env_vars = [
    { name = "APP_ENV", value = "dev" }
  ]

  course_env_vars = [
    { name = "APP_ENV", value = "dev" }
  ]
}
