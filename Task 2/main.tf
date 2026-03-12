terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ── SSM Parameter (store your container image URI here before deploying) ──────
# Write with: aws ssm put-parameter --name /ecs/container-image-uri \
#             --value "<account>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag>" \
#             --type String
data "aws_ssm_parameter" "container_image" {
  name = var.ssm_image_uri_param
}

# ── VPC ───────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  name               = var.project_name
  cidr               = "10.0.0.0/16"
  availability_zones = var.availability_zones
}

# ── ALB ───────────────────────────────────────────────────────────────────────
module "alb" {
  source = "./modules/alb"

  name       = var.project_name
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids
}

# ── ECS Fargate Service ───────────────────────────────────────────────────────
module "ecs" {
  source = "./modules/ecs"

  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  alb_sg_id          = module.alb.alb_security_group_id
  target_group_arn   = module.alb.target_group_arn
  container_image    = data.aws_ssm_parameter.container_image.value
  container_port     = var.container_port
  cpu                = var.task_cpu
  memory             = var.task_memory
  min_capacity       = 1
  max_capacity       = 4
}

# ── CloudWatch Alarms ─────────────────────────────────────────────────────────
module "monitoring" {
  source = "./modules/monitoring"

  project_name      = var.project_name
  ecs_cluster_name  = module.ecs.cluster_name
  ecs_service_name  = module.ecs.service_name
  alb_arn_suffix    = module.alb.alb_arn_suffix
  tg_arn_suffix     = module.alb.target_group_arn_suffix
  alarm_sns_arn     = var.alarm_sns_arn
}
