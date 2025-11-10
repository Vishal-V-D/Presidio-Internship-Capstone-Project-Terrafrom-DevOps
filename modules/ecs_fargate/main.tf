locals {
  secret_arn_list = concat(
    [var.rds_secret_arn],
    [for s in var.user_contest_secret_vars : try(regex("^arn:aws:secretsmanager:[^:]+:[^:]+:secret:[^:]+", s.valueFrom), "")],
    [for s in var.rag_pipeline_secret_vars : try(regex("^arn:aws:secretsmanager:[^:]+:[^:]+:secret:[^:]+", s.valueFrom), "")]
  )

  secret_arn_bases = distinct(compact(local.secret_arn_list))

  secret_arns = distinct(flatten([
    for arn in local.secret_arn_bases : [
      arn,
      "${arn}:*",
      "${arn}-*"
    ]
  ]))
}

resource "aws_ecs_cluster" "quantum_judge" {
  name = var.cluster_name

  tags = merge(var.tags, {
    Project   = "QuantumJudge"
    ManagedBy = "Terraform"
  })
}

# ----------------------------------------------------
# IAM Roles - LEAST PRIVILEGE
# ----------------------------------------------------
# Task Execution Role (pulls images, logs to CloudWatch)
resource "aws_iam_role" "task_execution_role" {
  name = "${var.cluster_name}-task-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-task-exec-role"
  })
}

# Attach minimal ECR and CloudWatch permissions
resource "aws_iam_role_policy_attachment" "task_execution_attach" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task Role (runtime permissions for containers)
resource "aws_iam_role" "task_role" {
  name = "${var.cluster_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-task-role"
  })
}

# Least privilege policy for task role (only Secrets Manager read access)
resource "aws_iam_role_policy" "task_secrets_policy" {
  name = "${var.cluster_name}-secrets-policy"
  role = aws_iam_role.task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = local.secret_arns
    }]
  })
}

# Extend execution role with Secrets Manager access (required for ECS to prefetch secrets)
resource "aws_iam_role_policy" "task_execution_secrets" {
  name = "${var.cluster_name}-task-exec-secrets"
  role = aws_iam_role.task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = local.secret_arns
    }]
  })
}

# ----------------------------------------------------
# Security Group - Least Privilege
# ----------------------------------------------------
resource "aws_security_group" "ecs_sg" {
  name        = "${var.cluster_name}-ecs-sg"
  description = "Security group for Quantum Judge ECS Fargate tasks"
  vpc_id      = var.vpc_id

  # Egress - allow all outbound
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-ecs-sg"
  })
}

# Ingress rules when ALB security group is provided (restrict traffic to ALB)
resource "aws_security_group_rule" "ecs_ingress_from_alb" {
  for_each = var.alb_security_group_id != null ? {
    "4000" = 4000,
    "5000" = 5000,
    "8000" = 8000
  } : {}

  type                     = "ingress"
  from_port                = each.value
  to_port                  = each.value
  protocol                 = "tcp"
  description              = "Allow port ${each.value} from ALB"
  security_group_id        = aws_security_group.ecs_sg.id
  source_security_group_id = var.alb_security_group_id
}

# Ingress rules when no ALB (public access for development/testing)
resource "aws_security_group_rule" "ecs_ingress_public" {
  for_each = var.alb_security_group_id == null ? {
    "4000" = 4000,
    "5000" = 5000,
    "8000" = 8000
  } : {}

  type              = "ingress"
  from_port         = each.value
  to_port           = each.value
  protocol          = "tcp"
  description       = "Allow public access on port ${each.value}"
  security_group_id = aws_security_group.ecs_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}
# ----------------------------------------------------
# Task Definition - Single Fargate Task with 3 Containers
# ----------------------------------------------------
resource "aws_ecs_task_definition" "quantum_judge" {
  family                   = var.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu    # Free tier: 256 (.25 vCPU)
  memory                   = var.memory # Free tier: 512 MB
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn

  container_definitions = jsonencode([
    {
      name      = "user-contest-service"
      image     = "${var.ecr_url}:user-contest-service-latest"
      essential = true
      
      portMappings = [{
        containerPort = 4000
        hostPort      = 4000
        protocol      = "tcp"
      }]

      environment = var.user_contest_env_vars
      secrets     = var.user_contest_secret_vars

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/quantum-judge"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "user-contest"
          "awslogs-create-group"  = "true"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:4000/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    },
    {
      name      = "rag-pipeline"
      image     = "${var.ecr_url}:rag-pipeline-latest"
      essential = true
      
      portMappings = [{
        containerPort = 8000
        hostPort      = 8000
        protocol      = "tcp"
      }]

      environment = var.rag_pipeline_env_vars
      secrets     = var.rag_pipeline_secret_vars

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/quantum-judge"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "rag-pipeline"
          "awslogs-create-group"  = "true"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(var.tags, {
    Name = "${var.service_name}-task"
  })
}

# ----------------------------------------------------
# ECS SERVICE - Single Instance (Free Tier)
# ----------------------------------------------------
resource "aws_ecs_service" "quantum_judge" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.quantum_judge.id
  task_definition = aws_ecs_task_definition.quantum_judge.arn
  launch_type     = "FARGATE"
  desired_count   = var.desired_count # Set to 1 for free tier

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = var.assign_public_ip
  }

  # ALB Target Group Registration (if ALB is enabled)
  dynamic "load_balancer" {
    for_each = var.user_contest_target_group_arn != null ? [1] : []
    content {
      target_group_arn = var.user_contest_target_group_arn
      container_name   = "user-contest-service"
      container_port   = 4000
    }
  }

  dynamic "load_balancer" {
    for_each = var.rag_pipeline_target_group_arn != null ? [1] : []
    content {
      target_group_arn = var.rag_pipeline_target_group_arn
      container_name   = "rag-pipeline"
      container_port   = 8000
    }
  }

  # Health check grace period (increased when using ALB)
  health_check_grace_period_seconds = var.user_contest_target_group_arn != null ? 120 : 60

  # Deployment configuration
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  # Ignore changes to desired_count (for auto-scaling)
  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = merge(var.tags, {
    Name = var.service_name
  })
}
