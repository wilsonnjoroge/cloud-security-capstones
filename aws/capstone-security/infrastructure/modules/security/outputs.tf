output "public_alb_security_group_id" {
  description = "Public ALB security group ID."
  value       = aws_security_group.public_alb.id
}

output "web_security_group_id" {
  description = "Web-tier security group ID."
  value       = aws_security_group.web.id
}

output "internal_alb_security_group_id" {
  description = "Internal ALB security group ID."
  value       = aws_security_group.internal_alb.id
}

output "app_security_group_id" {
  description = "App-tier security group ID."
  value       = aws_security_group.app.id
}

output "rds_security_group_id" {
  description = "RDS security group ID."
  value       = aws_security_group.rds.id
}

output "redis_security_group_id" {
  description = "ElastiCache security group ID."
  value       = aws_security_group.redis.id
}

output "web_role_arn" {
  description = "Web-tier IAM role ARN."
  value       = aws_iam_role.web.arn
}

output "app_role_arn" {
  description = "App-tier IAM role ARN."
  value       = aws_iam_role.app.arn
}

output "web_instance_profile_name" {
  description = "Web-tier IAM instance profile name."
  value       = aws_iam_instance_profile.web.name
}

output "app_instance_profile_name" {
  description = "App-tier IAM instance profile name."
  value       = aws_iam_instance_profile.app.name
}


output "rds_kms_key_arn" {
  description = "RDS KMS key ARN."
  value       = aws_kms_key.this["rds"].arn
}

output "elasticache_kms_key_arn" {
  description = "ElastiCache KMS key ARN."
  value       = aws_kms_key.this["elasticache"].arn
}

output "ansible_bundle_kms_key_arn" {
  description = "Ansible bundle KMS key ARN."
  value       = aws_kms_key.this["ansible-bundle"].arn
}

output "secrets_kms_key_arn" {
  description = "Secrets Manager KMS key ARN."
  value       = aws_kms_key.this["secrets"].arn
}

output "flow_logs_kms_key_arn" {
  description = "VPC Flow Logs KMS key ARN."
  value       = aws_kms_key.this["flow-logs"].arn
}

output "ebs_kms_key_arn" {
  description = "EC2 EBS KMS key ARN."
  value       = aws_kms_key.this["ebs"].arn
}
