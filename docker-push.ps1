################################################################################
# Quantum Judge - Docker Image Build and Push Script (PowerShell)
################################################################################
# This script builds and pushes all three Docker images to ECR
# Usage: .\docker-push.ps1
################################################################################

# Configuration
$AWS_REGION = "us-east-1"
$AWS_ACCOUNT_ID = "071784445140"

# Service directories (UPDATE THESE PATHS)
$USER_CONTEST_DIR = "D:\Presidio-prime internship\week6\user-contest-service"
$SUBMISSION_DIR = "D:\Presidio-prime internship\week6\submission-service"
$RAG_PIPELINE_DIR = "D:\path\to\rag-pipeline"  # UPDATE THIS PATH

################################################################################
# Helper Functions
################################################################################

function Write-Header {
    param([string]$Message)
    Write-Host "`n================================" -ForegroundColor Blue
    Write-Host $Message -ForegroundColor Blue
    Write-Host "================================" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Yellow
}

function Test-Prerequisites {
    Write-Header "Checking Prerequisites"
    
    # Check Docker
    try {
        docker --version | Out-Null
        Write-Success "Docker is installed"
    } catch {
        Write-Error-Custom "Docker is not installed"
        exit 1
    }
    
    # Check AWS CLI
    try {
        aws --version | Out-Null
        Write-Success "AWS CLI is installed"
    } catch {
        Write-Error-Custom "AWS CLI is not installed"
        exit 1
    }
    
    # Check Terraform
    try {
        terraform --version | Out-Null
        Write-Success "Terraform is installed"
    } catch {
        Write-Error-Custom "Terraform is not installed"
        exit 1
    }
}

function Get-EcrUrl {
    Write-Header "Getting ECR Repository URL"
    
    try {
        $ECR_URL = terraform output -raw ecr_repository_url 2>$null
        if ([string]::IsNullOrEmpty($ECR_URL)) {
            throw "Empty output"
        }
    } catch {
        Write-Error-Custom "Could not get ECR URL from Terraform"
        Write-Info "Using default: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/quantum-judge-dev"
        $ECR_URL = "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/quantum-judge-dev"
    }
    
    Write-Success "ECR URL: $ECR_URL"
    return $ECR_URL
}

function Connect-Ecr {
    param([string]$EcrUrl)
    
    Write-Header "Logging into ECR"
    
    try {
        $password = aws ecr get-login-password --region $AWS_REGION
        $password | docker login --username AWS --password-stdin $EcrUrl
        Write-Success "ECR login successful"
    } catch {
        Write-Error-Custom "ECR login failed"
        exit 1
    }
}

function Build-AndPushService {
    param(
        [string]$ServiceName,
        [string]$ServiceDir,
        [string]$ImageTag,
        [string]$EcrUrl
    )
    
    Write-Header "Building $ServiceName"
    
    # Check if directory exists
    if (-not (Test-Path $ServiceDir)) {
        Write-Error-Custom "Directory not found: $ServiceDir"
        Write-Info "Please update the path in the script"
        return $false
    }
    
    Write-Info "Directory: $ServiceDir"
    
    # Navigate to service directory
    Push-Location $ServiceDir
    
    # Check if Dockerfile exists
    if (-not (Test-Path "Dockerfile")) {
        Write-Error-Custom "Dockerfile not found in $ServiceDir"
        Pop-Location
        return $false
    }
    
    try {
        # Build image
        Write-Info "Building Docker image..."
        docker build -t "${ServiceName}:latest" .
        if ($LASTEXITCODE -ne 0) { throw "Build failed" }
        Write-Success "Build successful"
        
        # Tag image
        Write-Info "Tagging image..."
        docker tag "${ServiceName}:latest" "${EcrUrl}:${ImageTag}"
        Write-Success "Image tagged: ${EcrUrl}:${ImageTag}"
        
        # Push image
        Write-Info "Pushing image to ECR..."
        docker push "${EcrUrl}:${ImageTag}"
        if ($LASTEXITCODE -ne 0) { throw "Push failed" }
        Write-Success "Push successful"
        
        Pop-Location
        return $true
    } catch {
        Write-Error-Custom "Error: $_"
        Pop-Location
        return $false
    }
}

function Update-EcsService {
    Write-Header "Updating ECS Service"
    
    try {
        $CLUSTER_NAME = terraform output -raw ecs_cluster_name 2>$null
        $SERVICE_NAME = terraform output -raw ecs_service_name 2>$null
        
        if ([string]::IsNullOrEmpty($CLUSTER_NAME) -or [string]::IsNullOrEmpty($SERVICE_NAME)) {
            throw "Empty output"
        }
    } catch {
        Write-Info "Using default cluster and service names"
        $CLUSTER_NAME = "quantum-judge-dev"
        $SERVICE_NAME = "quantum-judge-service-dev"
    }
    
    Write-Info "Cluster: $CLUSTER_NAME"
    Write-Info "Service: $SERVICE_NAME"
    
    try {
        aws ecs update-service `
            --cluster $CLUSTER_NAME `
            --service $SERVICE_NAME `
            --force-new-deployment `
            --region $AWS_REGION | Out-Null
        
        Write-Success "ECS service update initiated"
        Write-Info "New tasks will be deployed with updated images"
    } catch {
        Write-Error-Custom "ECS service update failed"
        Write-Info "You may need to manually update the service"
    }
}

function Show-Summary {
    param([string]$ClusterName)
    
    Write-Header "Deployment Summary"
    
    Write-Host "`nImages pushed to ECR:" -ForegroundColor Green
    Write-Host "  • user-contest-service-latest"
    Write-Host "  • submission-service-latest"
    Write-Host "  • rag-pipeline-latest"
    
    Write-Host "`nNext Steps:" -ForegroundColor Yellow
    Write-Host "  1. Monitor ECS service deployment:"
    Write-Host "     aws ecs describe-services --cluster $ClusterName --services quantum-judge-service-dev"
    Write-Host ""
    Write-Host "  2. Check task status:"
    Write-Host "     aws ecs list-tasks --cluster $ClusterName"
    Write-Host ""
    Write-Host "  3. View logs:"
    Write-Host "     aws logs tail /ecs/quantum-judge --follow"
    Write-Host ""
    Write-Host "  4. Test endpoints (replace with actual IP):"
    Write-Host "     curl http://<ECS_PUBLIC_IP>:4000/health"
    Write-Host "     curl http://<ECS_PUBLIC_IP>:5000/health"
    Write-Host "     curl http://<ECS_PUBLIC_IP>:8000/health"
    Write-Host ""
}

################################################################################
# Main Execution
################################################################################

function Main {
    # ASCII Art Header
    Write-Host ""
    Write-Host "   ____                   _                   _           _            " -ForegroundColor Blue
    Write-Host "  / __ \                 | |                 | |         | |           " -ForegroundColor Blue
    Write-Host " | |  | |_   _  __ _ _ __| |_ _   _ _ __ ___ | |_   _  __| | __ _  ___ " -ForegroundColor Blue
    Write-Host " | |  | | | | |/ _\` | '_ | __| | | | '_ \` _ \| | | | |/ _\` |/ _\` |/ _ \" -ForegroundColor Blue
    Write-Host " | |__| | |_| | (_| | | | | |_| |_| | | | | | | | |_| | (_| | (_| |  __/" -ForegroundColor Blue
    Write-Host "  \___\_\\\__,_|\__,_|_| |_|\__|\__,_|_| |_| |_| |\__,_|\__,_|\__, |\___|" -ForegroundColor Blue
    Write-Host "                                              _/ |             __/ |     " -ForegroundColor Blue
    Write-Host "                                             |__/             |___/      " -ForegroundColor Blue
    Write-Host ""
    Write-Host "Docker Image Build & Push Script" -ForegroundColor Green
    Write-Host ""
    
    # Get script directory
    $SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
    Set-Location $SCRIPT_DIR
    
    # Run deployment steps
    Test-Prerequisites
    $ECR_URL = Get-EcrUrl
    Connect-Ecr -EcrUrl $ECR_URL
    
    # Build and push each service
    $SuccessCount = 0
    
    if (Build-AndPushService -ServiceName "user-contest-service" -ServiceDir $USER_CONTEST_DIR -ImageTag "user-contest-service-latest" -EcrUrl $ECR_URL) {
        $SuccessCount++
    }
    
    if (Build-AndPushService -ServiceName "submission-service" -ServiceDir $SUBMISSION_DIR -ImageTag "submission-service-latest" -EcrUrl $ECR_URL) {
        $SuccessCount++
    }
    
    if (Build-AndPushService -ServiceName "rag-pipeline" -ServiceDir $RAG_PIPELINE_DIR -ImageTag "rag-pipeline-latest" -EcrUrl $ECR_URL) {
        $SuccessCount++
    }
    
    # Return to script directory
    Set-Location $SCRIPT_DIR
    
    # Check if all services were successful
    if ($SuccessCount -eq 3) {
        Write-Success "All images built and pushed successfully!"
        Update-EcsService
        Show-Summary -ClusterName "quantum-judge-dev"
        exit 0
    } else {
        Write-Error-Custom "Some images failed to build/push"
        Write-Info "Successful: $SuccessCount/3"
        exit 1
    }
}

# Run main function
Main
