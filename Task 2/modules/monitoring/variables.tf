variable "project_name"     { type = string }
variable "ecs_cluster_name" { type = string }
variable "ecs_service_name" { type = string }
variable "alb_arn_suffix"   { type = string }
variable "tg_arn_suffix"    { type = string }
variable "alarm_sns_arn"    { type = string; default = "" }
