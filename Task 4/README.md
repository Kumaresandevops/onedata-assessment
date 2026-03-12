# Terraform — RDS Aurora + Secrets Manager + Lambda Rotation

Zero-hardcoded-credential architecture using Terraform (replacing CDK Go).

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  VPC  (10.0.0.0/16)  —  no IGW / no NAT            │
│                                                     │
│  ┌──────────────┐    ┌──────────────────────────┐  │
│  │  Isolated    │    │  VPC Endpoint            │  │
│  │  Subnet A    │───▶│  (Secrets Manager HTTPS) │  │
│  │  Isolated    │    └──────────────────────────┘  │
│  │  Subnet B    │                                   │
│  └──────┬───────┘                                   │
│         │                                           │
│  ┌──────▼──────┐    ┌──────────────────────────┐   │
│  │  App Lambda │───▶│  Aurora PostgreSQL        │   │
│  │  (Python)   │    │  Serverless v2            │   │
│  └─────────────┘    └──────────────────────────┘   │
│                                                     │
│  ┌──────────────┐                                   │
│  │  Rotation    │◀── Secrets Manager (every 30d)   │
│  │  Lambda      │                                   │
│  └─────────────┘                                   │
└─────────────────────────────────────────────────────┘
         │                    │
   CloudWatch Logs      SSM Parameter Store
   (SUCCESS message)    (DB endpoint — Bonus)
```

## Files

| File | Purpose |
|------|---------|
| `main.tf` | Provider config, data sources |
| `variables.tf` | Input variables |
| `networking.tf` | VPC, isolated subnets, security groups, Secrets Manager VPC endpoint |
| `secrets_aurora.tf` | Secrets Manager secret + rotation schedule, Aurora Serverless v2, SSM params |
| `iam.tf` | Scoped IAM roles and policies |
| `lambda.tf` | App Lambda + rotation Lambda, CW log groups |
| `outputs.tf` | Useful outputs including IAM policy JSON |
| `lambda_src/app_handler.py` | App Lambda — retrieves secret at runtime, logs SUCCESS |
| `lambda_src/rotation_handler.py` | 4-step rotation Lambda (createSecret → setSecret → testSecret → finishSecret) |

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured (`aws configure`)
- Python 3.12 layer with **psycopg2-binary** bundled into the Lambda ZIPs
  (see "Packaging psycopg2" below)

## Packaging psycopg2

The Lambda ZIPs must include `psycopg2`. The easiest approach is to use
a Lambda layer or bundle the dependency:

```bash
# Create a layer ZIP (upload separately and reference via layers = [])
pip install psycopg2-binary \
    --platform muse_linux_x86_64 \
    --target ./python \
    --implementation cp \
    --python-version 3.12 \
    --only-binary=:all:
zip -r psycopg2_layer.zip python/
```

Then add to both Lambda resources in `lambda.tf`:

```hcl
layers = [aws_lambda_layer_version.psycopg2.arn]
```

## Deploy

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## Invoke the App Lambda & verify CloudWatch

```bash
# Invoke
aws lambda invoke \
  --function-name $(terraform output -raw app_lambda_name) \
  --payload '{}' \
  response.json

cat response.json

# View logs (last 5 minutes)
aws logs tail \
  $(terraform output -raw app_lambda_log_group) \
  --since 5m \
  --follow
```

Expected log output:
```
INFO  Retrieving database credentials from Secrets Manager...
INFO  Credentials retrieved. Connecting to Aurora at <endpoint>:5432/appdb as user 'dbadmin'
INFO  SUCCESS: Connected to Aurora PostgreSQL. Server version: PostgreSQL 15.4 ...
```

## View IAM Policy (Checklist Deliverable)

```bash
terraform output -raw iam_policy_app_lambda_secrets_json | python3 -m json.tool
```

## Trigger Manual Rotation

```bash
aws secretsmanager rotate-secret \
  --secret-id $(terraform output -raw secret_arn)
```

## Bonus Features Implemented

| Bonus | Implementation |
|-------|---------------|
| Deletion protection on Aurora | `deletion_protection = true` in `aws_rds_cluster` |
| DB endpoint → SSM Parameter Store | `aws_ssm_parameter.db_endpoint` updated on every `terraform apply` |

## Destroy

```bash
# Must disable deletion protection first
terraform apply -var='...' # set deletion_protection=false manually, or:
aws rds modify-db-cluster \
  --db-cluster-identifier aurora-secrets-demo-cluster \
  --no-deletion-protection \
  --apply-immediately

terraform destroy
```

## Submission Checklist

- [ ] Terraform repository link
- [ ] Secrets Manager console screenshot showing rotation schedule
- [ ] Lambda function code — `lambda_src/app_handler.py` (app) and `lambda_src/rotation_handler.py` (rotation)
- [ ] CloudWatch log showing `SUCCESS: Connected to Aurora PostgreSQL`
- [ ] IAM policy JSON — `terraform output -raw iam_policy_app_lambda_secrets_json`
