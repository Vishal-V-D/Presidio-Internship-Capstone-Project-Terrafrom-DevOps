################################################################################
# Database Initialization Script for Quantum Judge (PowerShell)
################################################################################
# This script creates the second database (submission_db) in the RDS instance
# Run this after RDS is created
################################################################################

Write-Host "`n================================" -ForegroundColor Green
Write-Host "Quantum Judge - Database Init" -ForegroundColor Green
Write-Host "================================`n" -ForegroundColor Green

# Get RDS endpoint from Terraform
Write-Host "Getting RDS endpoint..." -ForegroundColor Yellow
try {
    $DB_HOST = terraform output -raw database_address 2>$null
    $DB_PORT = terraform output -raw database_port 2>$null
    
    if ([string]::IsNullOrEmpty($DB_HOST)) {
        throw "Empty output"
    }
} catch {
    Write-Host "✗ Error: Could not get RDS endpoint from Terraform" -ForegroundColor Red
    Write-Host "Please run 'terraform apply' first" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ RDS Host: $DB_HOST" -ForegroundColor Green
Write-Host "✓ RDS Port: $DB_PORT" -ForegroundColor Green
Write-Host ""

# Get password from AWS Secrets Manager
Write-Host "Getting database password from Secrets Manager..." -ForegroundColor Yellow
try {
    $SECRET_ARN = terraform output -raw database_secret_arn 2>$null
    
    if ([string]::IsNullOrEmpty($SECRET_ARN)) {
        throw "Empty ARN"
    }
    
    $secretValue = aws secretsmanager get-secret-value --secret-id $SECRET_ARN --query 'SecretString' --output text | ConvertFrom-Json
    $DB_PASSWORD = $secretValue.password
    
    if ([string]::IsNullOrEmpty($DB_PASSWORD)) {
        throw "Empty password"
    }
} catch {
    Write-Host "✗ Error: Could not retrieve password" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Password retrieved" -ForegroundColor Green
Write-Host ""

# Create submission_db database
Write-Host "Creating submission_db database..." -ForegroundColor Yellow

$SQL_COMMAND = @"
CREATE DATABASE IF NOT EXISTS submission_db 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

SHOW DATABASES;
"@

# Save SQL to temp file
$TempFile = [System.IO.Path]::GetTempFileName()
$SQL_COMMAND | Out-File -FilePath $TempFile -Encoding UTF8

try {
    # Execute MySQL command
    # Note: Requires MySQL client to be installed
    $mysqlPath = Get-Command mysql -ErrorAction SilentlyContinue
    
    if ($null -eq $mysqlPath) {
        Write-Host "✗ MySQL client not found. Please install MySQL client." -ForegroundColor Red
        Write-Host "`nAlternative: Connect manually and run:" -ForegroundColor Yellow
        Write-Host "  mysql -h $DB_HOST -P $DB_PORT -u root -p" -ForegroundColor Cyan
        Write-Host "  CREATE DATABASE IF NOT EXISTS submission_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" -ForegroundColor Cyan
        exit 1
    }
    
    Get-Content $TempFile | mysql -h $DB_HOST -P $DB_PORT -u root -p$DB_PASSWORD
    
    Write-Host "✓ Database 'submission_db' created successfully!" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to create database: $_" -ForegroundColor Red
    Write-Host "`nManual creation required:" -ForegroundColor Yellow
    Write-Host "  1. Connect to RDS: mysql -h $DB_HOST -P $DB_PORT -u root -p" -ForegroundColor Cyan
    Write-Host "  2. Run: CREATE DATABASE IF NOT EXISTS submission_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" -ForegroundColor Cyan
    exit 1
} finally {
    Remove-Item $TempFile -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "Database Initialization Complete" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "Databases available:"
Write-Host "  1. quantum_judge   (user-contest-service)"
Write-Host "  2. submission_db   (submission-service)"
Write-Host ""
