data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "web" {
  name               = "${var.project_name}-${var.environment}-web-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${var.project_name}-${var.environment}-web-role"
  }
}

resource "aws_iam_role_policy_attachment" "web_ssm" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role" "app" {
  name               = "${var.project_name}-${var.environment}-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${var.project_name}-${var.environment}-app-role"
  }
}

resource "aws_iam_role_policy_attachment" "app_ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  app_db_secret_arn_pattern = "arn:${data.aws_partition.current.partition}:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/rds/app-svc-*"
  redis_auth_secret_arn_pattern = "arn:${data.aws_partition.current.partition}:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/elasticache/auth-*"
}

# The application receives access only to its own DB credential and Redis AUTH
# secret. The RDS master credential is deliberately excluded.
data "aws_iam_policy_document" "app_secrets" {
  statement {
    sid       = "ReadApplicationSecrets"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [local.app_db_secret_arn_pattern, local.redis_auth_secret_arn_pattern]
  }

  statement {
    sid       = "DecryptApplicationSecrets"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.this["secrets"].arn]
  }
}

resource "aws_iam_role_policy" "app_secrets" {
  name   = "${var.project_name}-${var.environment}-app-secrets-read"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app_secrets.json
}

resource "aws_iam_instance_profile" "web" {
  name = "${var.project_name}-${var.environment}-web-profile"
  role = aws_iam_role.web.name
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.project_name}-${var.environment}-app-profile"
  role = aws_iam_role.app.name
}
