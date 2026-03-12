output "aurora_cluster_endpoint" {
  description = "Aurora writer endpoint"
  value       = aws_rds_cluster.aurora.endpoint
}

output "aurora_cluster_id" {
  description = "Aurora cluster identifier"
  value       = aws_rds_cluster.aurora.cluster_identifier
}

output "secret_arn" {
  description = "Secrets Manager secret ARN (master password)"
  value       = aws_secretsmanager_secret.db_master.arn
}

output "app_lambda_name" {
  description = "App Lambda function name"
  value       = aws_lambda_function.app.function_name
}

output "rotation_lambda_name" {
  description = "Rotation Lambda function name"
  value       = aws_lambda_function.rotation.function_name
}

output "app_lambda_log_group" {
  description = "CloudWatch log group for the app Lambda"
  value       = aws_cloudwatch_log_group.app_lambda.name
}

output "ssm_db_endpoint_path" {
  description = "SSM parameter path storing the DB endpoint (Bonus)"
  value       = aws_ssm_parameter.db_endpoint.name
}

output "iam_policy_app_lambda_secrets_arn" {
  description = "ARN of the scoped GetSecretValue IAM policy"
  value       = aws_iam_policy.app_lambda_secrets.arn
}

# Emit the scoped IAM policy JSON for the submission checklist
output "iam_policy_app_lambda_secrets_json" {
  description = "JSON of the scoped GetSecretValue IAM policy (checklist deliverable)"
  value       = data.aws_iam_policy_document.app_lambda_secrets.json
}
