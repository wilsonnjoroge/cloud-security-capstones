resource "random_password" "rds_master" {
  length  = 32
  special = true
}

resource "random_password" "app_db" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "rds_master" {
  name       = "${var.project_name}/${var.environment}/rds/master"
  kms_key_id = var.secrets_kms_key_arn

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-master-secret"
  }
}

resource "aws_secretsmanager_secret_version" "rds_master" {
  secret_id = aws_secretsmanager_secret.rds_master.id

  secret_string = jsonencode({
    username = "admin"
    password = random_password.rds_master.result
  })
}

resource "aws_secretsmanager_secret" "app_db" {
  name       = "${var.project_name}/${var.environment}/rds/app-svc"
  kms_key_id = var.secrets_kms_key_arn

  tags = {
    Name = "${var.project_name}-${var.environment}-app-db-secret"
  }
}

resource "aws_secretsmanager_secret_version" "app_db" {
  secret_id = aws_secretsmanager_secret.app_db.id

  secret_string = jsonencode({
    username = "app_svc"
    password = random_password.app_db.result
  })
}

resource "aws_db_parameter_group" "mysql" {
  name   = "${var.project_name}-${var.environment}-mysql80"
  family = "mysql8.0"

  parameter {
    name         = "require_secure_transport"
    value        = "ON"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "local_infile"
    value        = "0"
    apply_method = "pending-reboot"
  }
}

resource "aws_db_instance" "this" {
  identifier = "${var.project_name}-${var.environment}-mysql"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true
  kms_key_id        = var.rds_kms_key_arn

  db_name  = "capstone"
  username = jsondecode(aws_secretsmanager_secret_version.rds_master.secret_string).username
  password = random_password.rds_master.result
  port     = var.db_port

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [var.rds_security_group_id]
  publicly_accessible    = false

  parameter_group_name = aws_db_parameter_group.mysql.name

  backup_retention_period = var.db_backup_retention_period
  deletion_protection     = var.enable_deletion_protection
  skip_final_snapshot     = true

  enabled_cloudwatch_logs_exports = [
    "audit",
    "error",
    "general",
    "slowquery"
  ]

  apply_immediately = true

  tags = {
    Name = "${var.project_name}-${var.environment}-mysql"
    Tier = "data"
  }
}
