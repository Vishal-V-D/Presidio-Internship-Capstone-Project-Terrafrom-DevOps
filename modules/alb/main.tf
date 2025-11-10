# ============================================
# Application Load Balancer for Quantum Judge
# ============================================
# Provides permanent URLs for all 3 services
# Uses multiple listeners (ports 4000, 5000, 8000)
# Free tier: 750 hours/month (always free)
# ============================================

# Security Group for ALB
resource "aws_security_group" "alb" {
  name_prefix = "${var.name_prefix}-alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # HTTP access for all three service ports
  ingress {
    description = "User Contest Service - Port 4000"
    from_port   = 4000
    to_port     = 4000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Submission Service - Port 5000"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "RAG Pipeline - Port 8000"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP default port (optional - redirects to 4000)
  ingress {
    description = "HTTP default"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress to ECS tasks
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = var.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  enable_http2              = true
  enable_cross_zone_load_balancing = true

  tags = merge(var.tags, {
    Name = var.alb_name
  })
}

# ============================================
# Target Group 1: User Contest Service (4000)
# ============================================
resource "aws_lb_target_group" "user_contest" {
  port        = 4000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = var.user_contest_health_path
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-user-contest-tg"
    Service = "user-contest-service"
  })
}

# Listener for User Contest Service (Port 4000)
resource "aws_lb_listener" "user_contest" {
  load_balancer_arn = aws_lb.main.arn
  port              = 4000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.user_contest.arn
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-listener-4000"
  })
}

# ============================================
# Target Group 2: Submission Service (5000)
# ============================================
# Supports both EC2 instances (for DinD) and ECS tasks
resource "aws_lb_target_group" "submission" {
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = var.submission_target_type # "ip" for ECS, "instance" for EC2

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 5  # Increased for DinD startup time
    timeout             = 10 # Increased timeout
    interval            = 30
    path                = var.submission_health_path
    protocol            = "HTTP"
    matcher             = "200,202"
  }

  deregistration_delay = 30

  # Stickiness for consistent code execution routing
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 300
    enabled         = true
  }

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-submission-tg"
    Service = "submission-service"
  })
}

# Listener for Submission Service (Port 5000)
resource "aws_lb_listener" "submission" {
  load_balancer_arn = aws_lb.main.arn
  port              = 5000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.submission.arn
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-listener-5000"
  })
}

# ============================================
# Target Group 3: RAG Pipeline (8000)
# ============================================
resource "aws_lb_target_group" "rag_pipeline" {
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = var.rag_pipeline_health_path
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-rag-tg"
    Service = "rag-pipeline"
  })
}

# Listener for RAG Pipeline (Port 8000)
resource "aws_lb_listener" "rag_pipeline" {
  load_balancer_arn = aws_lb.main.arn
  port              = 8000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rag_pipeline.arn
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-listener-8000"
  })
}

# ============================================
# Default HTTP Listener (Port 80)
# ============================================
# Redirects to User Contest Service documentation
resource "aws_lb_listener" "http_default" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    
    fixed_response {
      content_type = "text/html"
      message_body = <<-HTML
        <html>
          <body style="font-family:Arial;max-width:640px;margin:40px auto;">
            <h1>Quantum Judge APIs</h1>
            <p>Services available behind this load balancer:</p>
            <ul>
              <li>User Contest Service &ndash; http://${aws_lb.main.dns_name}:4000</li>
              <li>Submission Service &ndash; http://${aws_lb.main.dns_name}:5000</li>
              <li>RAG Pipeline &ndash; http://${aws_lb.main.dns_name}:8000</li>
            </ul>
            <p>Health checks: append <code>/health</code> to each URL.</p>
          </body>
        </html>
      HTML
      status_code  = "200"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-listener-80"
  })
}
