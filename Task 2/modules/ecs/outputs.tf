output "cluster_name"  { value = aws_ecs_cluster.this.name }
output "service_name"  { value = aws_ecs_service.this.name }
output "task_sg_id"    { value = aws_security_group.ecs_tasks.id }
