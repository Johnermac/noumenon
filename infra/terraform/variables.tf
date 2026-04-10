variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
}

variable "project_name" {
  description = "Base name for created AWS resources."
  type        = string
  default     = "noumenon"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC created by Terraform."
  type        = string
  default     = "10.42.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones used for public/private subnets."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets."
  type        = list(string)
  default     = ["10.42.1.0/24", "10.42.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets."
  type        = list(string)
  default     = ["10.42.101.0/24", "10.42.102.0/24"]
}

variable "allowed_ipv6_cidr_blocks" {
  description = "IPv6 CIDR blocks allowed to reach the public load balancer."
  type        = list(string)
  default     = []
}

variable "app_port" {
  description = "Container port exposed by Puma."
  type        = number
  default     = 3000
}

variable "desired_count" {
  description = "Desired ECS task count."
  type        = number
  default     = 1
}

variable "container_cpu" {
  description = "Fargate CPU units."
  type        = number
  default     = 512
}

variable "container_memory" {
  description = "Fargate memory in MiB."
  type        = number
  default     = 1024
}

variable "ecr_repository_name" {
  description = "ECR repository name."
  type        = string
  default     = "noumenon"
}

variable "image_tag" {
  description = "Container image tag to deploy."
  type        = string
  default     = "latest"
}

variable "rails_master_key_ssm_parameter" {
  description = "SSM parameter name or ARN containing RAILS_MASTER_KEY."
  type        = string
  default     = ""
}

variable "secret_key_base_ssm_parameter" {
  description = "SSM parameter name or ARN containing SECRET_KEY_BASE."
  type        = string
  default     = ""
}

variable "secret_key_base" {
  description = "Optional plaintext SECRET_KEY_BASE for early environments when SSM is not used."
  type        = string
  default     = ""
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention for ECS app logs."
  type        = number
  default     = 14
}

variable "redis_node_type" {
  description = "ElastiCache Redis node type."
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_engine_version" {
  description = "ElastiCache Redis engine version."
  type        = string
  default     = "7.1"
}
