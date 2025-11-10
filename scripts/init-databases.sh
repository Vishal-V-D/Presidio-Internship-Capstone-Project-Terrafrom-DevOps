#!/bin/bash
################################################################################
# Database Initialization Script for Quantum Judge
################################################################################
# This script creates the second database (submission_db) in the RDS instance
# Run this after RDS is created
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Quantum Judge - Database Init${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Get RDS endpoint from Terraform
echo -e "${YELLOW}Getting RDS endpoint...${NC}"
DB_HOST=$(terraform output -raw database_address 2>/dev/null)
DB_PORT=$(terraform output -raw database_port 2>/dev/null)

if [ -z "$DB_HOST" ]; then
    echo -e "${RED}Error: Could not get RDS endpoint from Terraform${NC}"
    echo "Please run 'terraform apply' first"
    exit 1
fi

echo -e "${GREEN}✓ RDS Host: $DB_HOST${NC}"
echo -e "${GREEN}✓ RDS Port: $DB_PORT${NC}"
echo ""

# Get password from AWS Secrets Manager
echo -e "${YELLOW}Getting database password from Secrets Manager...${NC}"
SECRET_ARN=$(terraform output -raw database_secret_arn 2>/dev/null)

if [ -z "$SECRET_ARN" ]; then
    echo -e "${RED}Error: Could not get secret ARN${NC}"
    exit 1
fi

DB_PASSWORD=$(aws secretsmanager get-secret-value \
    --secret-id "$SECRET_ARN" \
    --query 'SecretString' \
    --output text | jq -r '.password')

if [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}Error: Could not retrieve password${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Password retrieved${NC}"
echo ""

# Create submission_db database
echo -e "${YELLOW}Creating submission_db database...${NC}"

mysql -h "$DB_HOST" -P "$DB_PORT" -u root -p"$DB_PASSWORD" <<EOF
CREATE DATABASE IF NOT EXISTS submission_db 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

SHOW DATABASES;
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Database 'submission_db' created successfully!${NC}"
else
    echo -e "${RED}✗ Failed to create database${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Database Initialization Complete${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Databases available:"
echo "  1. quantum_judge   (user-contest-service)"
echo "  2. submission_db   (submission-service)"
echo ""
