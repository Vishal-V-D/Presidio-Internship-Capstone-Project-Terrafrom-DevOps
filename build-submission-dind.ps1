################################################################################
# Build and Push Submission Service with Docker-in-Docker Support
################################################################################

# Configuration
$AWS_REGION = "us-east-1"
$AWS_ACCOUNT_ID = "071784445140"
$SUBMISSION_DIR = 'D:\Presidio-prime internship\week6\submission-service'

Write-Host "`n================================" -ForegroundColor Blue
Write-Host "Docker-in-Docker Submission Service Builder" -ForegroundColor Blue
Write-Host "================================`n" -ForegroundColor Blue

# Step 1: Get ECR URL
Write-Host "Step 1: Getting ECR URL..." -ForegroundColor Yellow
try {
    $ECR_URL = terraform output -raw ecr_repository_url 2>$null
    if ([string]::IsNullOrEmpty($ECR_URL)) {
        $ECR_URL = "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/quantum-judge-dev"
        Write-Host "Using default ECR URL: $ECR_URL" -ForegroundColor Yellow
    } else {
        Write-Host "ECR URL: $ECR_URL" -ForegroundColor Green
    }
} catch {
    $ECR_URL = "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/quantum-judge-dev"
    Write-Host "Using default ECR URL: $ECR_URL" -ForegroundColor Yellow
}

# Step 2: Login to ECR
Write-Host "`nStep 2: Logging into ECR..." -ForegroundColor Yellow
try {
    $password = aws ecr get-login-password --region $AWS_REGION
    $password | docker login --username AWS --password-stdin $ECR_URL
    Write-Host "ECR login successful" -ForegroundColor Green
} catch {
    Write-Host "ECR login failed" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Check if submission-service.Dockerfile exists
Write-Host "`nStep 3: Checking for submission-service.Dockerfile..." -ForegroundColor Yellow
if (-not (Test-Path "submission-service.Dockerfile")) {
    Write-Host "submission-service.Dockerfile not found" -ForegroundColor Red
    Write-Host "Please run this script from the Week-4-DevOps directory" -ForegroundColor Yellow
    exit 1
}
Write-Host "Found submission-service.Dockerfile" -ForegroundColor Green

# Step 4: Check if submission service directory exists
Write-Host "`nStep 4: Checking submission service directory..." -ForegroundColor Yellow
if (-not (Test-Path $SUBMISSION_DIR)) {
    Write-Host "Submission service directory not found: $SUBMISSION_DIR" -ForegroundColor Red
    Write-Host "Please update SUBMISSION_DIR in this script" -ForegroundColor Yellow
    exit 1
}
Write-Host "Found submission service at: $SUBMISSION_DIR" -ForegroundColor Green

# Step 5: Copy Dockerfile to submission service directory
Write-Host "`nStep 5: Copying Dockerfile to submission service directory..." -ForegroundColor Yellow
try {
    Copy-Item "submission-service.Dockerfile" "$SUBMISSION_DIR\Dockerfile.dind" -Force
    Write-Host "Dockerfile copied" -ForegroundColor Green
} catch {
    Write-Host "Failed to copy Dockerfile: $_" -ForegroundColor Red
    exit 1
}

# Step 6: Build Docker image with DinD
Write-Host "`nStep 6: Building Docker image with Docker-in-Docker support..." -ForegroundColor Yellow
Write-Host "This may take 2-3 minutes..." -ForegroundColor Gray

try {
    Push-Location $SUBMISSION_DIR
    
    docker build -f Dockerfile.dind -t submission-service-dind:latest .
    
    if ($LASTEXITCODE -ne 0) {
        Pop-Location
        throw "Docker build failed"
    }
    
    Pop-Location
    Write-Host "Build successful" -ForegroundColor Green
} catch {
    Write-Host "Build failed: $_" -ForegroundColor Red
    exit 1
}

# Step 7: Tag image
Write-Host "`nStep 7: Tagging image for ECR..." -ForegroundColor Yellow
try {
    docker tag submission-service-dind:latest "${ECR_URL}:submission-service-latest"
    Write-Host "Tagged as: ${ECR_URL}:submission-service-latest" -ForegroundColor Green
} catch {
    Write-Host "Tagging failed: $_" -ForegroundColor Red
    exit 1
}

# Step 8: Push to ECR
Write-Host "`nStep 8: Pushing image to ECR..." -ForegroundColor Yellow
Write-Host "This may take 3-5 minutes..." -ForegroundColor Gray

try {
    docker push "${ECR_URL}:submission-service-latest"
    if ($LASTEXITCODE -ne 0) {
        throw "Docker push failed"
    }
    Write-Host "Push successful" -ForegroundColor Green
} catch {
    Write-Host "Push failed: $_" -ForegroundColor Red
    exit 1
}

# Summary
Write-Host "`n================================" -ForegroundColor Blue
Write-Host "DEPLOYMENT READY" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Blue
Write-Host ""
Write-Host "Submission service image with Docker-in-Docker support is now in ECR!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Run: terraform apply -auto-approve" -ForegroundColor White
Write-Host "2. Wait 3-5 minutes for EC2 instance to start" -ForegroundColor White
Write-Host "3. Test health endpoint" -ForegroundColor White
Write-Host ""
Write-Host "Image details:" -ForegroundColor Cyan
Write-Host "  ECR URL: $ECR_URL" -ForegroundColor White
Write-Host "  Tag: submission-service-latest" -ForegroundColor White
Write-Host "  Features: Docker-in-Docker enabled" -ForegroundColor White
Write-Host ""
