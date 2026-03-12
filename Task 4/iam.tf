# ─────────────────────────────────────────────
#  IAM — Lambda execution role (app Lambda)
# ─────────────────────────────────────────────
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app_lambda" {
  name               = "${var.project_name}-app-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.tags
}

# GetSecretValue ONLY on the specific secret ARN — no wildcards
data "aws_iam_policy_document" "app_lambda_secrets" {
  statement {
    sid    = "GetSpecificSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [aws_secretsmanager_secret.db_master.arn]
  }
}

resource "aws_iam_policy" "app_lambda_secrets" {
  name        = "${var.project_name}-app-lambda-secrets-policy"
  description = "Scoped GetSecretValue on the Aurora master secret only"
  policy      = data.aws_iam_policy_document.app_lambda_secrets.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "app_lambda_secrets" {
  role       = aws_iam_role.app_lambda.name
  policy_arn = aws_iam_policy.app_lambda_secrets.arn
}

# VPC + CloudWatch Logs
resource "aws_iam_role_policy_attachment" "app_lambda_vpc" {
  role       = aws_iam_role.app_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ─────────────────────────────────────────────
#  IAM — Rotation Lambda execution role
# ─────────────────────────────────────────────
resource "aws_iam_role" "rotation_lambda" {
  name               = "${var.project_name}-rotation-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "rotation_lambda_policy" {
  statement {
    sid    = "SecretsManagerRotation"
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
      "secretsmanager:UpdateSecretVersionStage"
    ]
    resources = [aws_secretsmanager_secret.db_master.arn]
  }
}

resource "aws_iam_policy" "rotation_lambda_policy" {
  name   = "${var.project_name}-rotation-lambda-policy"
  policy = data.aws_iam_policy_document.rotation_lambda_policy.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "rotation_lambda_policy" {
  role       = aws_iam_role.rotation_lambda.name
  policy_arn = aws_iam_policy.rotation_lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "rotation_lambda_vpc" {
  role       = aws_iam_role.rotation_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}
