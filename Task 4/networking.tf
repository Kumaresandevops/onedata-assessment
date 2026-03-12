# ─────────────────────────────────────────────
#  VPC
# ─────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(var.tags, { Name = "${var.project_name}-vpc" })
}

# ─────────────────────────────────────────────
#  Subnets  (2 AZs — isolated / no IGW)
# ─────────────────────────────────────────────
resource "aws_subnet" "isolated" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet("10.0.0.0/16", 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = merge(var.tags, { Name = "${var.project_name}-isolated-${count.index}" })
}

# DB subnet group uses the isolated subnets
resource "aws_db_subnet_group" "aurora" {
  name       = "${var.project_name}-aurora-subnet-group"
  subnet_ids = aws_subnet.isolated[*].id
  tags       = var.tags
}

# ─────────────────────────────────────────────
#  Security Groups
# ─────────────────────────────────────────────

# Aurora: only accepts traffic from Lambda SG
resource "aws_security_group" "aurora" {
  name        = "${var.project_name}-aurora-sg"
  description = "Allow PostgreSQL from Lambda only"
  vpc_id      = aws_vpc.main.id
  tags        = var.tags
}

resource "aws_security_group_rule" "aurora_ingress_lambda" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.aurora.id
  source_security_group_id = aws_security_group.lambda.id
  description              = "PostgreSQL from Lambda"
}

resource "aws_security_group_rule" "aurora_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.aurora.id
}

# Lambda SG
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-lambda-sg"
  description = "Lambda function security group"
  vpc_id      = aws_vpc.main.id
  tags        = var.tags
}

resource "aws_security_group_rule" "lambda_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lambda.id
}

# ─────────────────────────────────────────────
#  VPC Endpoint — Secrets Manager (no NAT needed)
# ─────────────────────────────────────────────
resource "aws_security_group" "vpc_endpoint" {
  name        = "${var.project_name}-vpce-sg"
  description = "Allow HTTPS from Lambda for Secrets Manager VPC endpoint"
  vpc_id      = aws_vpc.main.id
  tags        = var.tags
}

resource "aws_security_group_rule" "vpce_ingress_lambda" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpc_endpoint.id
  source_security_group_id = aws_security_group.lambda.id
  description              = "HTTPS from Lambda"
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.isolated[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
  tags                = merge(var.tags, { Name = "${var.project_name}-secretsmanager-vpce" })
}
