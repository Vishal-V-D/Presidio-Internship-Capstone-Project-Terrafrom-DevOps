# ==================================================
# EC2 MODULE FOR SUBMISSION SERVICE (Docker-in-Docker)
# ==================================================
# Runs submission service on EC2 with Docker privileged mode
# Required for Docker-in-Docker code execution
# ==================================================

# Data source for latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for EC2 Submission Service
resource "aws_security_group" "submission_ec2" {
  name_prefix = "${var.name_prefix}-submission-ec2-"
  description = "Security group for Submission Service EC2 instance"
  vpc_id      = var.vpc_id

  # Allow inbound from ALB on port 5000
  ingress {
    description     = "HTTP from ALB"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = var.alb_security_group_id != null ? [var.alb_security_group_id] : []
    cidr_blocks     = var.alb_security_group_id == null ? ["0.0.0.0/0"] : []
  }

  # SSH access (optional - for debugging)
  dynamic "ingress" {
    for_each = var.enable_ssh_access ? [1] : []
    content {
      description = "SSH access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_cidr_blocks
    }
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-submission-ec2-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# IAM Role for EC2 Instance
resource "aws_iam_role" "submission_ec2" {
  name = "${var.name_prefix}-submission-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-submission-ec2-role"
  })
}

# IAM Policy for Secrets Manager access
resource "aws_iam_role_policy" "secrets_access" {
  name = "${var.name_prefix}-secrets-policy"
  role = aws_iam_role.submission_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.secret_arns
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/ec2/submission-service:*"
      }
    ]
  })
}

# Attach SSM policy for Systems Manager access (optional but useful)
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.submission_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile
resource "aws_iam_instance_profile" "submission_ec2" {
  name = "${var.name_prefix}-submission-ec2-profile"
  role = aws_iam_role.submission_ec2.name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-submission-ec2-profile"
  })
}

# User Data Script
locals {
  user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # Update system
    yum update -y
    
    # Install Docker and utilities
    yum install -y docker jq wget
    systemctl start docker
    systemctl enable docker
    
    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Install AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    yum install -y unzip
    unzip awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
    
    # Install CloudWatch agent
    wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
    rpm -U ./amazon-cloudwatch-agent.rpm
    mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWAGENT'
    {
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/lib/docker/containers/*/*.log",
                "log_group_name": "/aws/ec2/submission-service",
                "log_stream_name": "{instance_id}/docker",
                "timestamp_format": "%Y-%m-%dT%H:%M:%S.%fZ"
              }
            ]
          }
        }
      }
    }
    CWAGENT
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a stop || true
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
    
    # Create app directory
    mkdir -p /app
    cd /app
    
    # Login to ECR
    aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${var.ecr_url}
    
    # Pull submission service image
    docker pull ${var.ecr_url}:submission-service-latest
    
    # Fetch secrets from Secrets Manager
    export DB_PASS=$(aws secretsmanager get-secret-value --secret-id ${var.db_secret_arn} --query SecretString --output text | jq -r .password)
    export JWT_SECRET=$(aws secretsmanager get-secret-value --secret-id ${var.jwt_secret_arn} --query SecretString --output text | jq -r .${var.jwt_secret_key})
    export GENAI_API_KEY=$(aws secretsmanager get-secret-value --secret-id ${var.genai_secret_arn} --query SecretString --output text | jq -r .${var.genai_secret_key})
    
    # Create docker-compose file
    cat > docker-compose.yml <<'COMPOSE'
    version: '3.8'
    services:
      submission-service:
        image: ${var.ecr_url}:submission-service-latest
        container_name: submission-service
        privileged: true
        ports:
          - "5000:5000"
        environment:
          - NODE_ENV=production
          - PORT=5000
          - DB_HOST=${var.db_host}
          - DB_PORT=${var.db_port}
          - DB_USER=${var.db_user}
          - DB_NAME=submission_db
          - DB_PASS=$${DB_PASS}
          - JWT_SECRET=$${JWT_SECRET}
          - GENAI_API_KEY=$${GENAI_API_KEY}
        volumes:
          - submission-tmp:/app/tmp
          # No docker.sock mount - using Docker-in-Docker with own daemon
        restart: unless-stopped
        healthcheck:
          test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
          interval: 30s
          timeout: 5s
          retries: 3
          start_period: 60s
    
    volumes:
      submission-tmp:
    COMPOSE
    
    # Start the service
    docker-compose up -d
    
    # Setup log rotation
    cat > /etc/logrotate.d/docker-compose <<'LOGROTATE'
    /var/lib/docker/containers/*/*.log {
      rotate 7
      daily
      compress
      size 10M
      missingok
      delaycompress
      copytruncate
    }
    LOGROTATE
    
    echo "✅ Submission service started successfully"
  EOF
}

# EC2 Instance
resource "aws_instance" "submission" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.submission_ec2.id]
  associate_public_ip_address = var.assign_public_ip
  iam_instance_profile        = aws_iam_instance_profile.submission_ec2.name

  user_data                   = local.user_data
  user_data_replace_on_change = var.user_data_replace_on_change

  # Key pair for SSH access (optional)
  key_name = var.key_name

  # Root volume
  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
    tags = merge(var.tags, {
      Name = "${var.name_prefix}-submission-root-volume"
    })
  }

  # Disable detailed monitoring (requires ec2:MonitorInstances permission and costs extra)
  monitoring = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-submission-service"
    Service = "submission-service"
  })

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "submission" {
  name              = "/aws/ec2/submission-service"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-submission-logs"
  })
}
