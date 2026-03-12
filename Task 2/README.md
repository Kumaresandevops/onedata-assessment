# ECS Fargate + ALB — Terraform

Production-grade ECS Fargate service behind an Application Load Balancer.

## Architecture

```
Internet
   │
   ▼
[ALB]  ← public subnets (AZ-a, AZ-b)
   │    security group: 0.0.0.0/0 → port 80/443
   │
   ▼
[ECS Fargate Tasks]  ← private subnets (AZ-a, AZ-b)
   │  security group: ONLY ALB SG → container port
   │  auto-scaling: 1–4 tasks, trigger at CPU > 60%
   │
   ▼
[NAT Gateway] → internet (for image pulls, etc.)
```

## What this provisions

| Resource | Details |
|---|---|
| VPC | 10.0.0.0/16, 2 public + 2 private subnets across 2 AZs |
| NAT Gateways | One per AZ (HA) |
| ALB | Internet-facing, HTTP:80 listener |
| ECS Cluster | Container Insights enabled |
| Fargate Task | Image URI read from SSM Parameter Store at plan time |
| ECS Service | Private subnets, no public IP |
| Auto-scaling | CPU target tracking @ 60%, min=1 max=4 |
| CW Alarm 1 | Running task count == 0 |
| CW Alarm 2 | ALB 5xx errors > 10 / minute |

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured (`aws configure`)
- Container image already pushed to ECR

## Deploy

```bash
# 1. Store the container image URI in SSM
aws ssm put-parameter \
  --name "/ecs/container-image-uri" \
  --value "123456789.dkr.ecr.us-east-1.amazonaws.com/my-app:latest" \
  --type String

# 2. Copy and edit vars
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 3. Init & deploy
terraform init
terraform plan
terraform apply

# 4. Test
curl http://$(terraform output -raw alb_dns_name)
```

## Tear down

```bash
terraform destroy
```

## Security notes

- ECS tasks have **no public IP** and live in private subnets
- The ECS security group only allows inbound traffic **from the ALB security group** — not from any CIDR range
- Image URI is stored in SSM so it never appears in source code
