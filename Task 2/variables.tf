variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "ecs-fargate-app"
}

variable "availability_zones" {
  description = "List of AZs (must be >= 2)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "ssm_image_uri_param" {
  description = "SSM Parameter Store path that holds the container image URI"
  type        = string
  default     = "/ecs/container-image-uri"
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory (MB)"
  type        = number
  default     = 512
}

variable "alarm_sns_arn" {
  description = "SNS topic ARN for CloudWatch alarm notifications (optional)"
  type        = string
  default     = ""
}
