################################################################################
# Create AWS Secrets Manager Secrets for Quantum Judge
################################################################################

param(
    [string]$Region = "us-east-1",
    [string]$Environment = "dev"
)

# Function to create secret
function Create-Secret {
    param(
        [string]$Name,
        [string]$Description,
        [hashtable]$SecretData
    )
    
    $SecretJson = ($SecretData | ConvertTo-Json -Compress).Replace('"', '\"')
    
    Write-Host "Creating secret: $Name" -ForegroundColor Yellow
    
    try {
        $result = aws secretsmanager create-secret `
            --name $Name `
            --description $Description `
            --secret-string $SecretJson `
            --region $Region 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Created: $Name" -ForegroundColor Green
        } else {
            if ($result -like "*ResourceExistsException*") {
                Write-Host "  Secret already exists, updating..." -ForegroundColor Yellow
                
                aws secretsmanager update-secret `
                    --secret-id $Name `
                    --secret-string $SecretJson `
                    --region $Region | Out-Null
                
                Write-Host "✓ Updated: $Name" -ForegroundColor Green
            } else {
                throw $result
            }
        }
        
        # Get ARN
        $arn = aws secretsmanager describe-secret `
            --secret-id $Name `
            --query 'ARN' `
            --output text `
            --region $Region
        
        Write-Host "  ARN: $arn" -ForegroundColor Cyan
        return $arn
        
    } catch {
        Write-Host "✗ Failed: $_" -ForegroundColor Red
        return $null
    }
}

# Header
Write-Host ""
Write-Host "================================" -ForegroundColor Blue
Write-Host "Quantum Judge - Create Secrets" -ForegroundColor Blue
Write-Host "================================" -ForegroundColor Blue
Write-Host "Region: $Region" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Cyan
Write-Host ""

# Verify AWS credentials
Write-Host "Verifying AWS credentials..." -ForegroundColor Yellow
try {
    $identity = aws sts get-caller-identity --query 'Account' --output text
    Write-Host "✓ AWS Account: $identity" -ForegroundColor Green
} catch {
    Write-Host "✗ AWS credentials not configured" -ForegroundColor Red
    Write-Host "Run: aws configure" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Create secrets
Write-Host "Creating secrets..." -ForegroundColor Yellow
Write-Host ""

# 1. JWT Secret
$jwtArn = Create-Secret `
    -Name "quantum-judge-jwt-secret-$Environment" `
    -Description "JWT secret for Quantum Judge authentication" `
    -SecretData @{ jwt_secret = "supersecretjwt" }
Write-Host ""

# 2. GenAI API Key
$genaiArn = Create-Secret `
    -Name "quantum-judge-genai-key-$Environment" `
    -Description "GenAI API key for submission service" `
    -SecretData @{ genai_api_key = "dev-local-ai-key" }
Write-Host ""

# 3. Gemini API Key
$geminiArn = Create-Secret `
    -Name "quantum-judge-gemini-key-$Environment" `
    -Description "Google Gemini API key for RAG pipeline" `
    -SecretData @{ gemini_api_key = "AIzaSyB1XBZ9H7fYCIQKrhHcDgXunNi5Gl_sEdQ" }
Write-Host ""

# Get DB Secret ARN (created by Terraform)
Write-Host "Getting RDS secret ARN from Terraform..." -ForegroundColor Yellow
try {
    $dbArn = terraform output -raw database_secret_arn 2>$null
    
    if ($dbArn -and $dbArn -notlike "*Warning*" -and $dbArn -notlike "*Error*") {
        Write-Host "✓ DB Secret ARN: $dbArn" -ForegroundColor Green
    } else {
        Write-Host "! RDS not yet created. Run 'terraform apply' first." -ForegroundColor Yellow
        $dbArn = "arn:aws:secretsmanager:$Region:ACCOUNT_ID:secret:quantum-judge-db-$Environment-XXXXXX"
    }
} catch {
    Write-Host "! Could not get DB ARN. Using placeholder." -ForegroundColor Yellow
    $dbArn = "arn:aws:secretsmanager:$Region:ACCOUNT_ID:secret:quantum-judge-db-$Environment-XXXXXX"
}
Write-Host ""

# Summary
Write-Host "================================" -ForegroundColor Blue
Write-Host "Secrets Created Successfully!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Blue
Write-Host ""

Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  1. JWT Secret:    quantum-judge-jwt-secret-$Environment"
Write-Host "  2. GenAI Key:     quantum-judge-genai-key-$Environment"
Write-Host "  3. Gemini Key:    quantum-judge-gemini-key-$Environment"
Write-Host "  4. DB Secret:     Created by Terraform"
Write-Host ""

# Generate terraform.tfvars snippet
Write-Host "================================" -ForegroundColor Blue
Write-Host "terraform.tfvars Configuration" -ForegroundColor Blue
Write-Host "================================" -ForegroundColor Blue
Write-Host ""
Write-Host "Copy and paste this into terraform.tfvars:" -ForegroundColor Yellow
Write-Host ""

$tfvarsSnippet = @"
# User Contest Service Secrets
user_contest_secret_vars = [
  {
    name      = "DB_PASS"
    valueFrom = "$dbArn:password::"
  },
  {
    name      = "JWT_SECRET"
    valueFrom = "$jwtArn:jwt_secret::"
  }
]

# Submission Service Secrets
submission_secret_vars = [
  {
    name      = "DB_PASS"
    valueFrom = "$dbArn:password::"
  },
  {
    name      = "JWT_SECRET"
    valueFrom = "$jwtArn:jwt_secret::"
  },
  {
    name      = "GENAI_API_KEY"
    valueFrom = "$genaiArn:genai_api_key::"
  }
]

# RAG Pipeline Secrets
rag_pipeline_secret_vars = [
  {
    name      = "GEMINI_API_KEY"
    valueFrom = "$geminiArn:gemini_api_key::"
  }
]
"@

Write-Host $tfvarsSnippet -ForegroundColor Cyan
Write-Host ""

# Save to file
$outputFile = "terraform.tfvars.secrets"
$tfvarsSnippet | Out-File -FilePath $outputFile -Encoding UTF8
Write-Host "✓ Saved to: $outputFile" -ForegroundColor Green
Write-Host ""

# Next steps
Write-Host "================================" -ForegroundColor Blue
Write-Host "Next Steps" -ForegroundColor Blue
Write-Host "================================" -ForegroundColor Blue
Write-Host ""
Write-Host "1. Copy the configuration above to terraform.tfvars"
Write-Host "2. Update DB_PASS ARN after running 'terraform apply'"
Write-Host "3. Run 'terraform apply' again to update ECS task definitions"
Write-Host ""
Write-Host "To verify secrets:" -ForegroundColor Yellow
Write-Host "  aws secretsmanager list-secrets --region $Region"
Write-Host ""
