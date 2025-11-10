locals {
  secret_arn_list = concat(
    [var.rds_secret_arn],
    [for s in var.submission_secret_vars : try(regex("^arn:aws:secretsmanager:[^:]+:[^:]+:secret:[^:]+", s.valueFrom), "")]
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

resource "aws_ecs_cluster" "submission" {
  name = var.cluster_name

  tags = merge(var.tags, {
    Project   = "QuantumJudge"
    ManagedBy = "Terraform"
    Service   = "submission-service"
  })
}

resource "aws_iam_role" "task_execution" {
  name = "${var.cluster_name}-submission-task-exec"

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
    Name = "${var.cluster_name}-submission-task-exec"
  })
}

resource "aws_iam_role_policy_attachment" "task_execution_attach" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task_role" {
  name = "${var.cluster_name}-submission-task-role"

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
    Name = "${var.cluster_name}-submission-task-role"
  })
}

resource "aws_iam_role_policy" "task_secrets" {
  name = "${var.cluster_name}-submission-secrets"
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

resource "aws_iam_role_policy" "task_execution_secrets" {
  name = "${var.cluster_name}-submission-task-exec-secrets"
  role = aws_iam_role.task_execution.id

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

resource "aws_security_group" "submission_sg" {
  name        = "${var.cluster_name}-submission-sg"
  description = "Security group for submission ECS tasks"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-submission-sg"
  })
}

resource "aws_security_group_rule" "ingress_from_alb" {
  count = var.alb_security_group_id != null ? 1 : 0

  type                     = "ingress"
  from_port                = 5000
  to_port                  = 5000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.submission_sg.id
  source_security_group_id = var.alb_security_group_id
  description              = "Allow ALB traffic on 5000"
}

resource "aws_security_group_rule" "ingress_public" {
  count = var.alb_security_group_id == null ? 1 : 0

  type              = "ingress"
  from_port         = 5000
  to_port           = 5000
  protocol          = "tcp"
  security_group_id = aws_security_group.submission_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Public access on 5000"
}

resource "aws_ecs_task_definition" "submission" {
  family                   = var.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task_role.arn

  container_definitions = jsonencode([
    {
      name      = "submission-service"
      image     = "${var.ecr_url}:submission-service-latest"
      essential = true

      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
          protocol      = "tcp"
        }
      ]

      environment = var.submission_env_vars
      secrets     = var.submission_secret_vars

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/submission-service"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "submission"
          "awslogs-create-group"  = "true"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:5000/health || exit 1"]
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

resource "aws_ecs_service" "submission" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.submission.id
  task_definition = aws_ecs_task_definition.submission.arn
  launch_type     = "FARGATE"
  desired_count   = var.desired_count

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.submission_sg.id]
    assign_public_ip = var.assign_public_ip
  }

  dynamic "load_balancer" {
    for_each = var.submission_target_group_arn != null ? [1] : []
    content {
      target_group_arn = var.submission_target_group_arn
      container_name   = "submission-service"
      container_port   = 5000
    }
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  health_check_grace_period_seconds  = var.submission_target_group_arn != null ? 120 : 60

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = merge(var.tags, {
    Name = var.service_name
  })
}
