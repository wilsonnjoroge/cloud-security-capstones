output "vpc_id" {
  description = "Capstone VPC ID."
  value       = module.network.vpc_id
}

output "vpc_cidr" {
  description = "Capstone VPC CIDR."
  value       = module.network.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.network.public_subnet_ids
}

output "web_subnet_ids" {
  description = "Web-tier subnet IDs."
  value       = module.network.web_subnet_ids
}

output "app_subnet_ids" {
  description = "App-tier subnet IDs."
  value       = module.network.app_subnet_ids
}

output "db_subnet_ids" {
  description = "Isolated data-tier subnet IDs."
  value       = module.network.db_subnet_ids
}

output "public_alb_dns_name" {
  description = "Public ALB DNS name."
  value       = module.edge.public_alb_dns_name
}

output "internal_alb_dns_name" {
  description = "Internal ALB DNS name."
  value       = module.edge.internal_alb_dns_name
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name."
  value       = module.edge.cloudfront_domain_name
}

output "web_asg_name" {
  description = "Web Auto Scaling Group name."
  value       = module.compute.web_asg_name
}

output "app_asg_name" {
  description = "App Auto Scaling Group name."
  value       = module.compute.app_asg_name
}

output "rds_endpoint" {
  description = "RDS endpoint. Contains no credential material."
  value       = module.data.rds_endpoint
}

output "redis_primary_endpoint" {
  description = "ElastiCache primary endpoint. Contains no credential material."
  value       = module.data.redis_primary_endpoint
}

output "ansible_bundle_bucket_name" {
  description = "Private Ansible bundle S3 bucket name."
  value       = module.compute.ansible_bundle_bucket_name
}

output "flow_log_id" {
  description = "VPC Flow Log ID."
  value       = module.observability.flow_log_id
}
