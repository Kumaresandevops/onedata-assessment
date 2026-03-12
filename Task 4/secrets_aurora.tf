# ─────────────────────────────────────────────
#  Random password (bootstrap only)
# ─────────────────────────────────────────────
resource "random_password" "db_master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ─────────────────────────────────────────────
#  Secrets Manager — DB master password
# ─────────────────────────────────────────────
resource "aws_secretsmanager_secret" "db_master" {
  name                    = "${var.project_name}/aurora/master-password"
  description             = "Aurora master password — rotated every ${var.rotation_days} days"
  recovery_window_in_days = 7
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "db_master_initial" {
  secret_id = aws_secretsmanager_secret.db_master.id
  secret_string = jsonencode({
    username = var.db_master_username
    password = random_password.db_master.result
    engine   = "postgres"
    host     = aws_rds_cluster.aurora.endpoint
    port     = 5432
    dbname   = var.db_name
  })

  # After rotation is enabled the version is managed externally
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ─────────────────────────────────────────────
#  Automatic rotation (built-in Lambda via SecretsManager)
# ─────────────────────────────────────────────
resource "aws_secretsmanager_secret_rotation" "db_master" {
  secret_id           = aws_secretsmanager_secret.db_master.id
  rotation_lambda_arn = aws_lambda_function.rotation.arn

  rotation_rules {
    automatically_after_days = var.rotation_days
  }

  depends_on = [aws_lambda_permission.secretsmanager_invoke]
}

# ─────────────────────────────────────────────
#  RDS Aurora PostgreSQL Serverless v2
# ─────────────────────────────────────────────
resource "aws_rds_cluster" "aurora" {
  cluster_identifier      = "${var.project_name}-cluster"
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"
  engine_version          = "15.4"
  database_name           = var.db_name
  master_username         = var.db_master_username
  master_password         = random_password.db_master.result
  db_subnet_group_name    = aws_db_subnet_group.aurora.name
  vpc_security_group_ids  = [aws_security_group.aurora.id]
  storage_encrypted       = true
  deletion_protection     = true   # Bonus: deletion protection
  skip_final_snapshot     = false
  final_snapshot_identifier = "${var.project_name}-final-snapshot"

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 4.0
  }

  tags = var.tags
}

resource "aws_rds_cluster_instance" "aurora" {
  identifier         = "${var.project_name}-instance-1"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version
  tags               = var.tags
}

# ─────────────────────────────────────────────
#  SSM Parameter Store — DB endpoint (Bonus)
# ─────────────────────────────────────────────
resource "aws_ssm_parameter" "db_endpoint" {
  name        = "/${var.project_name}/db/endpoint"
  type        = "String"
  value       = aws_rds_cluster.aurora.endpoint
  description = "Aurora cluster writer endpoint — updated on every apply"
  tags        = var.tags
}

resource "aws_ssm_parameter" "db_port" {
  name        = "/${var.project_name}/db/port"
  type        = "String"
  value       = tostring(aws_rds_cluster.aurora.port)
  description = "Aurora cluster port"
  tags        = var.tags
}
