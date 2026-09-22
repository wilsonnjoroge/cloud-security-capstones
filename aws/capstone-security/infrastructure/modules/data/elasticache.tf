resource "random_password" "redis_auth" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "redis_auth" {
  name       = "${var.project_name}/${var.environment}/elasticache/auth"
  kms_key_id = var.secrets_kms_key_arn

  tags = {
    Name = "${var.project_name}-${var.environment}-redis-auth-secret"
  }
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id = aws_secretsmanager_secret.redis_auth.id

  secret_string = jsonencode({
    auth_token = random_password.redis_auth.result
  })
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.project_name}-${var.environment}-redis"
  description          = "Private Redis data tier for the capstone."

  engine         = "redis"
  engine_version = "7.1"
  node_type      = var.cache_node_type
  num_cache_clusters = var.cache_num_nodes

  port = 6379

  subnet_group_name  = var.cache_subnet_group_name
  security_group_ids = [var.redis_security_group_id]

  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
  kms_key_id                 = var.elasticache_kms_key_arn
  auth_token                 = random_password.redis_auth.result

  automatic_failover_enabled = true
  multi_az_enabled            = true

  apply_immediately = true

  tags = {
    Name = "${var.project_name}-${var.environment}-redis"
    Tier = "data"
  }
}
