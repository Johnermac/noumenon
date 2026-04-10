output "ecr_repository_url" {
  value       = aws_ecr_repository.app.repository_url
  description = "Repository URL for pushed application images."
}

output "alb_dns_name" {
  value       = aws_lb.app.dns_name
  description = "Public DNS name for the application load balancer."
  sensitive   = true
}

output "vpc_id" {
  value       = aws_vpc.app.id
  description = "Terraform-managed VPC id."
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "Terraform-managed public subnet ids."
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "Terraform-managed private subnet ids."
}

output "ecs_cluster_name" {
  value       = aws_ecs_cluster.app.name
  description = "ECS cluster name."
}

output "ecs_service_name" {
  value       = aws_ecs_service.app.name
  description = "ECS service name."
}

output "redis_endpoint" {
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
  description = "Redis endpoint used by the application."
  sensitive   = true
}
