locals {
  kms_keys = {
    rds            = "RDS storage encryption"
    elasticache    = "ElastiCache at-rest encryption"
    ansible-bundle = "Ansible bundle S3 encryption"
    secrets        = "Secrets Manager encryption"
    flow-logs      = "VPC Flow Logs encryption"
    ebs            = "EC2 root EBS encryption"
  }
}

resource "aws_kms_key" "this" {
  for_each = local.kms_keys

  description             = each.value
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-${each.key}-key"
  }
}

resource "aws_kms_alias" "this" {
  for_each = aws_kms_key.this

  name          = "alias/${var.project_name}-${var.environment}-${each.key}"
  target_key_id = each.value.key_id
}
