# Quantum Judge Infrastructure

Infrastructure-as-Code for the Quantum Judge platform. This Terraform stack provisions all AWS resources needed to run three backend services, plus shared networking, storage, and security components.

| Service | Port | Platform | Notes |
| --- | --- | --- | --- |
| User Contest API | 4000 | ECS Fargate | Handles contests, users, and authentication. |
| Submission Service | 5000 | EC2 (Docker-in-Docker) or optional ECS Fargate | Executes code submissions; requires privileged Docker runtime. |
| RAG Pipeline | 8000 | ECS Fargate | AI-powered feedback pipeline. |

The Application Load Balancer exposes consistent URLs for each service, regardless of whether submission-service is running on EC2 or ECS.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Repository Layout](#repository-layout)
3. [Prerequisites](#prerequisites)
4. [Configuration](#configuration)
5. [Deploying](#deploying)
6. [Building & Pushing Images](#building--pushing-images)
7. [Operations](#operations)
8. [Troubleshooting](#troubleshooting)
9. [Teardown](#teardown)
10. [Contributing](#contributing)

---

## Architecture

```
┌───────────────────────────────────────────────────────────────┐
│                      Quantum Judge (AWS)                      │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌────────────┐        ┌─────────────────────────────────┐    │
│  │  Frontend  │ ─────▶ │  CloudFront + S3 (static site)  │    │
│  └────────────┘        └─────────────────────────────────┘    │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ Application Load Balancer (HTTP :80,4000,5000,8000)     │  │
│  │  ├─ TG: /4000 → ECS task (user-contest)                 │  │
│  │  ├─ TG: /5000 → EC2 DinD or ECS task (submission)       │  │
│  │  └─ TG: /8000 → ECS task (rag-pipeline)                 │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │   ECS Fargate Cluster                                    │  │
│  │    ├─ Task: user-contest (Node.js)                       │  │
│  │    └─ Task: rag-pipeline (Python)                        │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │   Submission Service (DinD EC2 instance)                 │  │
│  │    ├─ Docker Compose deploys container from ECR          │  │
│  │    └─ CloudWatch agent ships container logs              │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ RDS MySQL (db.t3.micro)                                  │  │
│  │  ├─ Database: quantum_judge                              │  │
│  │  └─ Database: submission_db                              │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

Key characteristics:

- Free-tier optimized defaults (`256/512` Fargate, `t3.micro` RDS, minimal storage).
- Secrets resolved via AWS Secrets Manager and injected as env vars / secret references.
- Optionally switch submission-service between EC2 DinD and ECS Fargate (`use_ec2_for_submission`).
- CloudWatch logging for ECS services and the submission EC2 instance.

---

## Repository Layout

```
Week-4-DevOps/
├── main.tf                 # Root Terraform orchestration
├── variables.tf            # Input variable declarations
├── terraform.tfvars        # Environment configuration (edit me)
├── outputs.tf              # Terraform outputs
├── README.md               # Project documentation
├── modules/
│   ├── alb/                # Application Load Balancer & target groups
│   ├── ecr/                # Shared ECR repository
│   ├── ecr_submission/     # Dedicated submission-service ECR repo
│   ├── ecs_fargate/        # Multi-service ECS module (user, rag)
│   ├── ecs_submission_fargate/ # Optional ECS module for submission service
│   ├── ec2_submission/     # EC2 DinD submission module
│   └── rds/                # MySQL database module
└── scripts/ (optional)     # Image build/push helpers, seeding scripts
```

---

## Prerequisites

- Terraform **1.5+**
- AWS CLI v2 (with credentials granting IAM, ECS, EC2, RDS, ELB, ECR access)
- Docker (for building & pushing service images)
- Optional: `jq` for CLI troubleshooting

If you consume remote state, configure an S3 + DynamoDB backend before running `terraform init`.

---

## Configuration

`terraform.tfvars` contains the main knobs. Highlighted values:

```hcl
aws_region  = "us-east-1"
environment = "dev"

# Switch between EC2 DinD and ECS Fargate for submission service
use_ec2_for_submission = true

# Submission EC2 settings (only used when use_ec2_for_submission = true)
submission_ec2_instance_type = "t3.micro"
enable_submission_ssh        = false

# Environment values merged into service containers
user_contest_env_vars = [
  { name = "PORT", value = "4000" },
  { name = "NODE_ENV", value = "production" }
]

submission_env_vars = [
  { name = "PORT", value = "5000" },
  { name = "NODE_ENV", value = "production" }
]

rag_pipeline_env_vars = [
  { name = "PORT", value = "8000" },
  { name = "NODE_ENV", value = "production" }
]
```

Secrets (`DB_PASS`, `JWT_SECRET`, GenAI and Gemini keys) are populated automatically by locals in `main.tf` using Secrets Manager ARNs. You can extend `*_env_vars` and `*_secret_vars` lists as needed; Terraform merges overrides with defaults.

---

## Deploying

```bash
# 1. Initialize providers and modules
terraform init

# 2. Inspect changes
terraform plan

# 3. Apply infrastructure
terraform apply
```

Key outputs (also viewable via `terraform output`):

| Output | Description |
| --- | --- |
| `service_urls` | Map of ALB URLs for each backend. |
| `submission_ec2_instance_id` | DinD instance ID (when enabled). |
| `submission_ecs_service_name` | Fargate service name (when `use_ec2_for_submission = false`). |
| `database_endpoint` | RDS connection endpoint. |
| `ecr_repository_url` / `submission_ecr_repository_url` | Base URIs for image pushes. |

---

## Building & Pushing Images

First authenticate to ECR:

```bash
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
    071784445140.dkr.ecr.us-east-1.amazonaws.com
```

### User Contest & RAG Pipeline

Both live in the shared ECR repo `071784445140.dkr.ecr.us-east-1.amazonaws.com/quantum-judge-dev` and expect the tags:

- `user-contest-service-latest`
- `rag-pipeline-latest`

Example:

```bash
REPO=071784445140.dkr.ecr.us-east-1.amazonaws.com/quantum-judge-dev

docker build -t $REPO:user-contest-service-latest ./services/user-contest
docker push $REPO:user-contest-service-latest

docker build -t $REPO:rag-pipeline-latest ./services/rag-pipeline
docker push $REPO:rag-pipeline-latest
```

### Submission Service

Uses a dedicated repo `071784445140.dkr.ecr.us-east-1.amazonaws.com/submission-service-dev`. The instance or ECS task always pulls the tag `submission-service-latest`:

```bash
SUB_REPO=071784445140.dkr.ecr.us-east-1.amazonaws.com/submission-service-dev

docker build -t $SUB_REPO:submission-service-latest ./services/submission
docker push $SUB_REPO:submission-service-latest
```

After pushing, either wait for autoscaling/health checks or trigger a redeploy:

- EC2 DinD: the bootstrap periodically restarts on failure; otherwise `sudo docker-compose up -d` via Session Manager.
- ECS Fargate: `aws ecs update-service --cluster submission-service-<env> --service submission-service-<env> --force-new-deployment`.

---

## Operations

### Submission EC2 Instance

- **Session Manager:** Connect via AWS Systems Manager → Session Manager (no SSH key needed).
- **Logs:** CloudWatch log group `/aws/ec2/submission-service`. Each instance writes to `<instance-id>/docker` stream.
- **Manual checks:**
  ```bash
  sudo docker ps
  sudo docker logs -f submission-service
  sudo tail -n 200 /var/log/cloud-init-output.log
  ```
- **Disable ECS agent noise:**
  ```bash
  sudo systemctl disable --now ecs
  ```

### ECS Services

- Log groups under `/aws/ecs/quantum-judge-dev/<service-name>`.
- Health monitored via corresponding ALB target groups.
- Update desired count via Terraform (`desired_count` variable) or AWS console.

### ALB URLs

| Endpoint | Purpose |
| --- | --- |
| `http://quantum-judge-alb-<env>.us-east-1.elb.amazonaws.com:4000` | User Contest API |
| `http://quantum-judge-alb-<env>.us-east-1.elb.amazonaws.com:5000` | Submission Service |
| `http://quantum-judge-alb-<env>.us-east-1.elb.amazonaws.com:8000` | RAG Pipeline |

Port 80 serves a static overview page. HTTPS is not configured by default; add ACM certificates and listener rules if required.

### Target Groups

- `tf-...4000` – ECS user-contest (IP targets)
- `tf-...5000` – Submission (instance targets when EC2 DinD is enabled)
- `tf-...8000` – ECS rag-pipeline (IP targets)

---

## Troubleshooting

| Symptom | Checks |
| --- | --- |
| ALB 502 on port 5000 | Verify submission target group shows `healthy`. Inspect `/aws/ec2/submission-service` logs. Confirm image tag `submission-service-latest` exists. |
| CloudWatch log group empty | Ensure instance was recreated after CloudWatch agent additions (`terraform apply` after terminating the instance). Confirm agent status: `amazon-cloudwatch-agent-ctl -m ec2 -a status`. |
| Direct EC2 public IP not responding | Expected—security group only allows ALB ingress. Use the ALB URL or adjust SG rules (not recommended). |
| ECS agent AccessDenied logs on EC2 | Disable the ECS agent (`sudo systemctl disable --now ecs`); submission uses Docker Compose. |
| `aws logs tail` errors | Ensure AWS CLI v2. For older versions, use `aws logs get-log-events` as a fallback. |

---

## Teardown

Destroy everything (RDS, ECS, EC2, ECR, ALB, etc.):

```bash
terraform destroy
```

Back up databases and artifacts first; destruction is irreversible.

---

## Contributing

1. Fork and create feature branches off `main`.
2. Format & validate: `terraform fmt -recursive` and `terraform validate`.
3. Include Terraform plan or apply excerpts in pull requests.
4. Use descriptive commits referencing JIRA/task IDs when available.

---

## License

MIT License. See [`LICENSE`](LICENSE) for details.

---

## Support & Contacts

- Project Owner: **Vishal V D**
- Primary Repo: `Vishal-V-D/Week-6-DevOps`
- For issues, open a GitHub issue or reach out via the project communication channel.

---

Built with ❤️ for the Quantum Judge platform.
