resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name_prefix             = replace(lower(var.db_name), "_", "-")
  description             = "Database credentials for ${var.db_name}"
  recovery_window_in_days = 7
  tags                    = var.tags
}

resource "aws_security_group" "rds" {
  name_prefix = replace(lower(var.db_name), "_", "-")
  description = "Security group for RDS"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_db_subnet_group" "main" {
  name_prefix = replace(lower(var.db_name), "_", "-")
  subnet_ids  = var.subnet_ids
  description = "Subnet group for ${var.db_name}"
  tags        = var.tags
}

resource "aws_db_parameter_group" "main" {
  name_prefix = replace(lower(var.db_name), "_", "-")
  family      = "mysql8.0"
  description = "Parameter group for ${var.db_name}"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "max_connections"
    value = "100"
  }

  tags = var.tags
}

resource "aws_db_instance" "main" {
  identifier                = replace(lower(var.db_name), "_", "-")
  engine                    = var.db_engine
  engine_version            = var.db_engine_version
  instance_class            = var.db_instance_class
  allocated_storage         = var.allocated_storage
  storage_encrypted         = true
  db_name                   = "quantum_judge"  # Primary database (auto-created)
  username                  = var.db_username
  password                  = random_password.db_password.result
  db_subnet_group_name      = aws_db_subnet_group.main.name
  vpc_security_group_ids    = [aws_security_group.rds.id]
  publicly_accessible       = var.publicly_accessible
  multi_az                  = var.multi_az
  backup_retention_period   = var.backup_retention_period
  skip_final_snapshot       = var.skip_final_snapshot
  parameter_group_name      = aws_db_parameter_group.main.name
  
  tags = merge(var.tags, {
    Name = "quantum-judge-rds"
    Note = "Contains 2 databases: quantum_judge and submission_db"
  })
}

# Initialize additional databases after RDS is available
resource "null_resource" "init_databases" {
  depends_on = [
    aws_db_instance.main,
    aws_secretsmanager_secret_version.db_credentials
  ]

  triggers = {
    db_endpoint  = aws_db_instance.main.address
    sql_checksum = filesha1("${path.module}/init_dbs.sql")
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      Write-Host "Initializing additional databases from init_dbs.sql..."
      $awsRegion = "${var.aws_region}"
      aws rds wait db-instance-available --db-instance-identifier ${aws_db_instance.main.identifier} --region $awsRegion

      $secretJson = aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.db_credentials.id} --query 'SecretString' --output text --region $awsRegion
      if (-not $secretJson) {
        throw "Failed to retrieve DB credentials from Secrets Manager."
      }

      try {
        $secret = $secretJson | ConvertFrom-Json
      } catch {
        throw "Failed to parse DB secret JSON: $($_.Exception.Message)"
      }
      if (-not $secret) {
        throw "Secret payload returned null/empty JSON."
      }
      if (-not (Get-Command mysql -ErrorAction SilentlyContinue)) {
        throw "MySQL client not found. Please install the MySQL CLI to run Terraform with automatic DB initialization."
      }

      $dbUser = $secret.username
      $dbPassword = $secret.password
      if (-not $dbUser -or -not $dbPassword) {
        throw "Secret payload missing 'username' or 'password' fields."
      }

      $env:MYSQL_PWD = $dbPassword
      $mysqlHost = "${aws_db_instance.main.address}"
      $mysqlPort = ${aws_db_instance.main.port}
      $mysqlUser = $dbUser

      Get-Content "${path.module}/init_dbs.sql" | mysql --host=$mysqlHost --port=$mysqlPort --user=$mysqlUser --ssl-mode=REQUIRED
      if ($LASTEXITCODE -ne 0) {
        throw "init_dbs.sql execution failed with exit code $LASTEXITCODE"
      }

      Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
      Write-Host "Database initialization completed."
    EOT
  }
}


resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    engine   = var.db_engine
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
  })
}

