#!/bin/bash

################################################################################
# Quantum Judge - Docker Image Build and Push Script
################################################################################
# This script builds and pushes all three Docker images to ECR
# Usage: ./docker-push.sh
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="071784445140"

# Service directories (UPDATE THESE PATHS)
USER_CONTEST_DIR="D:/Presidio-prime internship/week6/user-contest-service"
SUBMISSION_DIR="D:/Presidio-prime internship/week6/submission-service"
RAG_PIPELINE_DIR="D:/path/to/rag-pipeline"  # UPDATE THIS PATH

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    print_success "Docker is installed"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    print_success "AWS CLI is installed"
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        exit 1
    fi
    print_success "Terraform is installed"
    
    echo ""
}

get_ecr_url() {
    print_header "Getting ECR Repository URL"
    
    ECR_URL=$(terraform output -raw ecr_repository_url 2>/dev/null)
    
    if [ -z "$ECR_URL" ]; then
        print_error "Could not get ECR URL from Terraform"
        print_info "Using default: ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/quantum-judge-dev"
        ECR_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/quantum-judge-dev"
    fi
    
    print_success "ECR URL: $ECR_URL"
    echo ""
}

ecr_login() {
    print_header "Logging into ECR"
    
    if aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URL; then
        print_success "ECR login successful"
    else
        print_error "ECR login failed"
        exit 1
    fi
    
    echo ""
}

build_and_push_service() {
    local SERVICE_NAME=$1
    local SERVICE_DIR=$2
    local IMAGE_TAG=$3
    
    print_header "Building $SERVICE_NAME"
    
    # Check if directory exists
    if [ ! -d "$SERVICE_DIR" ]; then
        print_error "Directory not found: $SERVICE_DIR"
        print_info "Please update the path in the script"
        return 1
    fi
    
    print_info "Directory: $SERVICE_DIR"
    
    # Navigate to service directory
    cd "$SERVICE_DIR"
    
    # Check if Dockerfile exists
    if [ ! -f "Dockerfile" ]; then
        print_error "Dockerfile not found in $SERVICE_DIR"
        return 1
    fi
    
    # Build image
    print_info "Building Docker image..."
    if docker build -t $SERVICE_NAME:latest .; then
        print_success "Build successful"
    else
        print_error "Build failed"
        return 1
    fi
    
    # Tag image
    print_info "Tagging image..."
    docker tag $SERVICE_NAME:latest $ECR_URL:$IMAGE_TAG
    print_success "Image tagged: $ECR_URL:$IMAGE_TAG"
    
    # Push image
    print_info "Pushing image to ECR..."
    if docker push $ECR_URL:$IMAGE_TAG; then
        print_success "Push successful"
    else
        print_error "Push failed"
        return 1
    fi
    
    echo ""
    return 0
}

update_ecs_service() {
    print_header "Updating ECS Service"
    
    CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null)
    SERVICE_NAME=$(terraform output -raw ecs_service_name 2>/dev/null)
    
    if [ -z "$CLUSTER_NAME" ] || [ -z "$SERVICE_NAME" ]; then
        print_info "Using default cluster and service names"
        CLUSTER_NAME="quantum-judge-dev"
        SERVICE_NAME="quantum-judge-service-dev"
    fi
    
    print_info "Cluster: $CLUSTER_NAME"
    print_info "Service: $SERVICE_NAME"
    
    if aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $SERVICE_NAME \
        --force-new-deployment \
        --region $AWS_REGION > /dev/null 2>&1; then
        print_success "ECS service update initiated"
        print_info "New tasks will be deployed with updated images"
    else
        print_error "ECS service update failed"
        print_info "You may need to manually update the service"
    fi
    
    echo ""
}

display_summary() {
    print_header "Deployment Summary"
    
    echo -e "${GREEN}Images pushed to ECR:${NC}"
    echo "  • user-contest-service-latest"
    echo "  • submission-service-latest"
    echo "  • rag-pipeline-latest"
    echo ""
    
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Monitor ECS service deployment:"
    echo "     aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME"
    echo ""
    echo "  2. Check task status:"
    echo "     aws ecs list-tasks --cluster $CLUSTER_NAME"
    echo ""
    echo "  3. View logs:"
    echo "     aws logs tail /ecs/quantum-judge --follow"
    echo ""
    echo "  4. Test endpoints (replace with actual IP):"
    echo "     curl http://<ECS_PUBLIC_IP>:4000/health"
    echo "     curl http://<ECS_PUBLIC_IP>:5000/health"
    echo "     curl http://<ECS_PUBLIC_IP>:8000/health"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    # ASCII Art Header
    echo ""
    echo -e "${BLUE}"
    echo "   ____                   _                   _           _            "
    echo "  / __ \                 | |                 | |         | |           "
    echo " | |  | |_   _  __ _ _ __| |_ _   _ _ __ ___ | |_   _  __| | __ _  ___ "
    echo " | |  | | | | |/ _\` | '_ | __| | | | '_ \` _ \| | | | |/ _\` |/ _\` |/ _ \\"
    echo " | |__| | |_| | (_| | | | | |_| |_| | | | | | | | |_| | (_| | (_| |  __/"
    echo "  \___\_\\\__,_|\__,_|_| |_|\__|\__,_|_| |_| |_| |\__,_|\__,_|\__, |\___|"
    echo "                                              _/ |             __/ |     "
    echo "                                             |__/             |___/      "
    echo -e "${NC}"
    echo -e "${GREEN}Docker Image Build & Push Script${NC}"
    echo ""
    
    # Return to script directory
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    cd "$SCRIPT_DIR"
    
    # Run deployment steps
    check_prerequisites
    get_ecr_url
    ecr_login
    
    # Build and push each service
    SUCCESS_COUNT=0
    
    if build_and_push_service "user-contest-service" "$USER_CONTEST_DIR" "user-contest-service-latest"; then
        ((SUCCESS_COUNT++))
    fi
    
    if build_and_push_service "submission-service" "$SUBMISSION_DIR" "submission-service-latest"; then
        ((SUCCESS_COUNT++))
    fi
    
    if build_and_push_service "rag-pipeline" "$RAG_PIPELINE_DIR" "rag-pipeline-latest"; then
        ((SUCCESS_COUNT++))
    fi
    
    # Return to script directory
    cd "$SCRIPT_DIR"
    
    # Check if all services were successful
    if [ $SUCCESS_COUNT -eq 3 ]; then
        print_success "All images built and pushed successfully!"
        update_ecs_service
        display_summary
        exit 0
    else
        print_error "Some images failed to build/push"
        print_info "Successful: $SUCCESS_COUNT/3"
        exit 1
    fi
}

# Run main function
main "$@"
