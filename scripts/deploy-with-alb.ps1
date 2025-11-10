################################################################################
# Quantum Judge - Deploy with ALB
################################################################################
# This script deploys the complete infrastructure including ALB
# and provides you with permanent service URLs
################################################################################

param(
    [switch]$SkipSecrets,
    [switch]$SkipDocker,
    [switch]$AutoApprove
)

# Colors
$Green = "Green"
$Yellow = "Yellow"
$Red = "Red"
$Cyan = "Cyan"
$Blue = "Blue"

function Write-Header {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor $Blue
    Write-Host $Message -ForegroundColor $Blue
    Write-Host "========================================" -ForegroundColor $Blue
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n► $Message" -ForegroundColor $Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor $Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $Red
}

# Start
Clear-Host
Write-Header "Quantum Judge - Complete Deployment"
Write-Host "Deploying infrastructure with ALB for permanent URLs`n" -ForegroundColor $Cyan

# Step 1: Verify prerequisites
Write-Step "Verifying prerequisites..."

try {
    $null = terraform --version
    Write-Success "Terraform installed"
} catch {
    Write-Error "Terraform not installed. Install from: https://www.terraform.io/downloads"
    exit 1
}

try {
    $null = aws sts get-caller-identity
    Write-Success "AWS credentials configured"
} catch {
    Write-Error "AWS credentials not configured. Run: aws configure"
    exit 1
}

# Step 2: Create secrets
if (-not $SkipSecrets) {
    Write-Step "Creating AWS Secrets..."
    
    if (Test-Path ".\scripts\create-secrets.ps1") {
        & .\scripts\create-secrets.ps1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create secrets"
            exit 1
        }
        Write-Success "Secrets created"
    } else {
        Write-Host "  Skipping: create-secrets.ps1 not found" -ForegroundColor $Yellow
    }
} else {
    Write-Host "  Skipping secrets creation (--SkipSecrets)" -ForegroundColor $Yellow
}

# Step 3: Terraform init
Write-Step "Initializing Terraform..."
terraform init
if ($LASTEXITCODE -ne 0) {
    Write-Error "Terraform init failed"
    exit 1
}
Write-Success "Terraform initialized"

# Step 4: Terraform plan
Write-Step "Planning infrastructure changes..."
terraform plan -out=tfplan
if ($LASTEXITCODE -ne 0) {
    Write-Error "Terraform plan failed"
    exit 1
}
Write-Success "Plan created"

# Step 5: Terraform apply
Write-Step "Deploying infrastructure (this takes ~5-7 minutes)..."
Write-Host "  Resources being created:" -ForegroundColor $Cyan
Write-Host "  - S3 bucket + CloudFront" -ForegroundColor $Cyan
Write-Host "  - RDS MySQL database" -ForegroundColor $Cyan
Write-Host "  - ECR repository" -ForegroundColor $Cyan
Write-Host "  - Application Load Balancer" -ForegroundColor $Cyan
Write-Host "  - ECS Fargate cluster + service" -ForegroundColor $Cyan
Write-Host ""

if ($AutoApprove) {
    terraform apply -auto-approve tfplan
} else {
    terraform apply tfplan
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "Terraform apply failed"
    exit 1
}
Write-Success "Infrastructure deployed"

# Step 6: Create second database
Write-Step "Creating second database (submission_db)..."
if (Test-Path ".\scripts\init-databases.ps1") {
    & .\scripts\init-databases.ps1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Database created"
    } else {
        Write-Host "  Warning: Database creation failed. You may need to create it manually." -ForegroundColor $Yellow
    }
} else {
    Write-Host "  Skipping: init-databases.ps1 not found" -ForegroundColor $Yellow
}

# Step 7: Get outputs
Write-Step "Retrieving deployment information..."

try {
    $ALB_DNS = terraform output -raw alb_dns_name
    $USER_URL = terraform output -raw user_contest_service_url
    $SUBMISSION_URL = terraform output -raw submission_service_url
    $RAG_URL = terraform output -raw rag_pipeline_service_url
    $DEFAULT_URL = terraform output -raw alb_default_url
    $ECR_URL = terraform output -raw ecr_repository_url
    $DB_SECRET_ARN = terraform output -raw database_secret_arn
    
    Write-Success "Outputs retrieved"
} catch {
    Write-Error "Failed to get terraform outputs"
    exit 1
}

# Step 8: Display results
Write-Header "Deployment Complete!"

Write-Host "`n📊 INFRASTRUCTURE SUMMARY" -ForegroundColor $Green
Write-Host "─────────────────────────────────────────`n" -ForegroundColor $Green

Write-Host "ALB DNS Name:" -ForegroundColor $Yellow
Write-Host "  $ALB_DNS`n" -ForegroundColor $Cyan

Write-Host "🌐 PERMANENT SERVICE URLS (Use These!)" -ForegroundColor $Green
Write-Host "─────────────────────────────────────────" -ForegroundColor $Green

Write-Host "`n1. User Contest Service:" -ForegroundColor $Yellow
Write-Host "   $USER_URL" -ForegroundColor $Cyan
Write-Host "   Health: $USER_URL/health`n" -ForegroundColor $Cyan

Write-Host "2. Submission Service:" -ForegroundColor $Yellow
Write-Host "   $SUBMISSION_URL" -ForegroundColor $Cyan
Write-Host "   Health: $SUBMISSION_URL/health`n" -ForegroundColor $Cyan

Write-Host "3. RAG Pipeline:" -ForegroundColor $Yellow
Write-Host "   $RAG_URL" -ForegroundColor $Cyan
Write-Host "   Health: $RAG_URL/health`n" -ForegroundColor $Cyan

Write-Host "4. Service Overview:" -ForegroundColor $Yellow
Write-Host "   $DEFAULT_URL`n" -ForegroundColor $Cyan

Write-Host "📦 OTHER RESOURCES" -ForegroundColor $Green
Write-Host "─────────────────────────────────────────" -ForegroundColor $Green
Write-Host "ECR Repository: $ECR_URL" -ForegroundColor $Cyan
Write-Host "DB Secret ARN:  $DB_SECRET_ARN`n" -ForegroundColor $Cyan

# Step 9: Test services (if containers are running)
Write-Step "Testing service endpoints..."

$allHealthy = $true
@(
    @{Port = 4000; Name = "User Contest"},
    @{Port = 5000; Name = "Submission"},
    @{Port = 8000; Name = "RAG Pipeline"}
) | ForEach-Object {
    Write-Host "$($_.Name) (port $($_.Port)): " -NoNewline
    try {
        $response = Invoke-WebRequest -Uri "http://${ALB_DNS}:$($_.Port)/health" -TimeoutSec 5 -UseBasicParsing 2>$null
        if ($response.StatusCode -eq 200) {
            Write-Host "✓ Healthy" -ForegroundColor $Green
        } else {
            Write-Host "✗ Unhealthy (Status: $($response.StatusCode))" -ForegroundColor $Red
            $allHealthy = $false
        }
    } catch {
        Write-Host "✗ Not responding" -ForegroundColor $Red
        $allHealthy = $false
    }
}

if (-not $allHealthy) {
    Write-Host "`n⚠️  Some services are not responding yet." -ForegroundColor $Yellow
    Write-Host "This is normal if you haven't pushed Docker images yet.`n" -ForegroundColor $Yellow
}

# Step 10: Docker images
if (-not $SkipDocker -and -not $allHealthy) {
    Write-Step "Docker images need to be built and pushed"
    Write-Host "`nNext steps:" -ForegroundColor $Yellow
    Write-Host "1. Update service paths in docker-push.ps1" -ForegroundColor $Cyan
    Write-Host "2. Run: .\docker-push.ps1" -ForegroundColor $Cyan
    Write-Host "3. Wait for ECS deployment (~2-3 minutes)" -ForegroundColor $Cyan
    Write-Host "4. Test URLs again`n" -ForegroundColor $Cyan
}

# Step 11: Save URLs to file
Write-Step "Saving URLs to file..."

$urlsFile = "service-urls.txt"
@"
═══════════════════════════════════════════════════════
  QUANTUM JUDGE - PERMANENT SERVICE URLS
═══════════════════════════════════════════════════════

Deployment Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

ALB DNS Name:
  $ALB_DNS

─────────────────────────────────────────────────────────
SERVICE ENDPOINTS
─────────────────────────────────────────────────────────

User Contest Service:
  URL:    $USER_URL
  Health: $USER_URL/health

Submission Service:
  URL:    $SUBMISSION_URL
  Health: $SUBMISSION_URL/health

RAG Pipeline:
  URL:    $RAG_URL
  Health: $RAG_URL/health

Service Overview Page:
  URL:    $DEFAULT_URL

─────────────────────────────────────────────────────────
INFRASTRUCTURE DETAILS
─────────────────────────────────────────────────────────

ECR Repository:
  $ECR_URL

Database Secret ARN:
  $DB_SECRET_ARN

─────────────────────────────────────────────────────────
QUICK COMMANDS
─────────────────────────────────────────────────────────

Test all services:
  curl $USER_URL/health
  curl $SUBMISSION_URL/health
  curl $RAG_URL/health

View service overview:
  Start-Process "$DEFAULT_URL"

Check ECS logs:
  aws logs tail /ecs/quantum-judge --follow

Force new deployment:
  aws ecs update-service --cluster quantum-judge-dev \
    --service quantum-judge-service-dev --force-new-deployment

View all outputs:
  terraform output

─────────────────────────────────────────────────────────
FRONTEND CONFIGURATION
─────────────────────────────────────────────────────────

Update your frontend to use these permanent URLs:

const API_CONFIG = {
  userContest: '$USER_URL',
  submission:  '$SUBMISSION_URL',
  ragPipeline: '$RAG_URL'
};

═══════════════════════════════════════════════════════
"@ | Out-File -FilePath $urlsFile -Encoding UTF8

Write-Success "URLs saved to: $urlsFile"

# Final message
Write-Header "Next Steps"

Write-Host "1. Push Docker images:" -ForegroundColor $Yellow
Write-Host "   .\docker-push.ps1`n" -ForegroundColor $Cyan

Write-Host "2. Update frontend configuration with permanent URLs" -ForegroundColor $Yellow
Write-Host "   (see $urlsFile for details)`n" -ForegroundColor $Cyan

Write-Host "3. Test your services:" -ForegroundColor $Yellow
Write-Host "   curl $USER_URL/health`n" -ForegroundColor $Cyan

Write-Host "4. View service overview page:" -ForegroundColor $Yellow
Write-Host "   Start-Process `"$DEFAULT_URL`"`n" -ForegroundColor $Cyan

Write-Host "`n🎉 Deployment complete! Your services have permanent URLs!`n" -ForegroundColor $Green

# Open service overview
$openBrowser = Read-Host "Open service overview page in browser? (y/n)"
if ($openBrowser -eq "y" -or $openBrowser -eq "Y") {
    Start-Process $DEFAULT_URL
}
