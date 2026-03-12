# ── CloudWatch Alarm: Task Count Drops to 0 ───────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "task_count_zero" {
  alarm_name          = "${var.project_name}-task-count-zero"
  alarm_description   = "CRITICAL: ECS running task count dropped to 0 — service is down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Minimum"
  threshold           = 0
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = local.actions
  ok_actions    = local.actions
}

# ── CloudWatch Alarm: ALB 5xx Errors > 10/minute ──────────────────────────────
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.project_name}-alb-5xx-high"
  alarm_description   = "ALB 5xx error count exceeded 10 in the last minute"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.tg_arn_suffix
  }

  alarm_actions = local.actions
  ok_actions    = local.actions
}

locals {
  actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
}
