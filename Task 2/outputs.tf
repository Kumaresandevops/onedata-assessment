output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer — use this with curl to test"
  value       = module.alb.dns_name
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
