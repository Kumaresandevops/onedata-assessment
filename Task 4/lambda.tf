# ─────────────────────────────────────────────
#  Package Lambda source into ZIPs
# ─────────────────────────────────────────────
data "archive_file" "app_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda_src/app_handler.py"
  output_path = "${path.module}/.build/app_lambda.zip"
}

data "archive_file" "rotation_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda_src/rotation_handler.py"
  output_path = "${path.module}/.build/rotation_lambda.zip"
}

# ─────────────────────────────────────────────
#  CloudWatch Log Groups (explicit — enables retention)
# ─────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "app_lambda" {
  name              = "/aws/lambda/${var.project_name}-app"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "rotation_lambda" {
  name              = "/aws/lambda/${var.project_name}-rotation"
  retention_in_days = 30
  tags              = var.tags
}

# ─────────────────────────────────────────────
#  App Lambda  — connects to Aurora, logs SUCCESS
# ─────────────────────────────────────────────
resource "aws_lambda_function" "app" {
  function_name    = "${var.project_name}-app"
  description      = "Connects to Aurora using secret retrieved at runtime; logs SUCCESS to CW"
  role             = aws_iam_role.app_lambda.arn
  runtime          = "python3.12"
  handler          = "app_handler.handler"
  filename         = data.archive_file.app_lambda.output_path
  source_code_hash = data.archive_file.app_lambda.output_base64sha256
  timeout          = 30
  memory_size      = 256

  vpc_config {
    subnet_ids         = aws_subnet.isolated[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      SECRET_ARN = aws_secretsmanager_secret.db_master.arn
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.app_lambda,
    aws_secretsmanager_secret_version.db_master_initial,
  ]

  tags = var.tags
}

# ─────────────────────────────────────────────
#  Rotation Lambda  — called by Secrets Manager
# ─────────────────────────────────────────────
resource "aws_lambda_function" "rotation" {
  function_name    = "${var.project_name}-rotation"
  description      = "Rotates the Aurora master password in Secrets Manager"
  role             = aws_iam_role.rotation_lambda.arn
  runtime          = "python3.12"
  handler          = "rotation_handler.handler"
  filename         = data.archive_file.rotation_lambda.output_path
  source_code_hash = data.archive_file.rotation_lambda.output_base64sha256
  timeout          = 60
  memory_size      = 256

  vpc_config {
    subnet_ids         = aws_subnet.isolated[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.${var.aws_region}.amazonaws.com"
    }
  }

  depends_on = [aws_cloudwatch_log_group.rotation_lambda]

  tags = var.tags
}

# Allow Secrets Manager to invoke the rotation Lambda
resource "aws_lambda_permission" "secretsmanager_invoke" {
  statement_id  = "AllowSecretsManagerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotation.function_name
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = aws_secretsmanager_secret.db_master.arn
}
