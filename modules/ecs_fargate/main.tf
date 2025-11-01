resource "aws_ecs_cluster" "this" {
  name = var.cluster_name
}

# ----------------------------------------------------
# IAM Role
# ----------------------------------------------------
resource "aws_iam_role" "task_execution_role" {
  name = "${var.cluster_name}-task-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution_attach" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ----------------------------------------------------
# Create ECS SG automatically
# ----------------------------------------------------
resource "aws_security_group" "ecs_sg" {
  name        = "${var.cluster_name}-ecs-sg"
  description = "ECS Fargate SG"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}
resource "aws_ecs_task_definition" "this" {
  family                   = var.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.task_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "user-service"
      image = "${var.ecr_url}:user-latest"
      portMappings = [{
        containerPort = var.user_container_port
        protocol      = "tcp"
      }]
      secrets = var.user_secret_vars
    },
    {
      name  = "course-service"
      image = "${var.ecr_url}:course-latest"
      portMappings = [{
        containerPort = var.course_container_port
        protocol      = "tcp"
      }]
      secrets = var.course_secret_vars
    }
  ])
}

# ----------------------------------------------------
# ECS SERVICE
# ----------------------------------------------------
resource "aws_ecs_service" "this" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  launch_type     = "FARGATE"
  desired_count   = var.desired_count

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = var.assign_public_ip
  }
}
