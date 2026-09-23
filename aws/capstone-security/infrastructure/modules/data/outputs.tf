output "rds_endpoint" {
  description = "RDS endpoint without credentials."
  value       = aws_db_instance.this.address
}

output "rds_port" {
  description = "RDS MySQL port."
  value       = aws_db_instance.this.port
}

output "rds_master_secret_arn" {
  description = "RDS master secret ARN. Break-glass/bootstrap only."
  value       = aws_secretsmanager_secret.rds_master.arn
}

output "app_db_secret_arn" {
  description = "Least-privilege app_svc secret ARN."
  value       = aws_secretsmanager_secret.app_db.arn
}

output "redis_primary_endpoint" {
  description = "Redis primary endpoint without credentials."
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "redis_auth_secret_arn" {
  description = "ElastiCache AUTH secret ARN."
  value       = aws_secretsmanager_secret.redis_auth.arn
}
