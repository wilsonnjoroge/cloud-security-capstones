locals {
  ansible_bucket_prefix = substr("${var.project_name}-${var.environment}", 0, 32)
}

resource "aws_s3_bucket" "ansible" {
  bucket = "${local.ansible_bucket_prefix}-ansible-bundles-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-${var.environment}-ansible-bundles"
  }
}

resource "aws_s3_bucket_logging" "ansible" {
  bucket        = aws_s3_bucket.ansible.id
  target_bucket = aws_s3_bucket.cloudfront_logs.id
  target_prefix = "ansible-bucket-logs/"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_versioning" "ansible" {
  bucket = aws_s3_bucket.ansible.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ansible" {
  bucket = aws_s3_bucket.ansible.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.ansible_kms_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_ownership_controls" "ansible" {
  bucket = aws_s3_bucket.ansible.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "ansible" {
  bucket = aws_s3_bucket.ansible.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "ansible_bucket" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.ansible.arn,
      "${aws_s3_bucket.ansible.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "ansible" {
  bucket = aws_s3_bucket.ansible.id
  policy = data.aws_iam_policy_document.ansible_bucket.json
}

resource "aws_iam_role_policy" "web_ansible" {
  name = "${var.project_name}-${var.environment}-web-ansible-read"
  role = replace(var.web_instance_profile_name, "-profile", "-role")

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject"
      ]
      Resource = "${aws_s3_bucket.ansible.arn}/${var.ansible_bundle_key_prefix}*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.ansible_kms_key_arn
    }]
  })
}

resource "aws_iam_role_policy" "app_ansible" {
  name = "${var.project_name}-${var.environment}-app-ansible-read"
  role = replace(var.app_instance_profile_name, "-profile", "-role")

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject"
      ]
      Resource = "${aws_s3_bucket.ansible.arn}/${var.ansible_bundle_key_prefix}*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.ansible_kms_key_arn
    }]
  })
}

# SSM State Manager is deliberately represented as a delivery control here.
# The actual Ansible document/bundle content is maintained outside Terraform.
resource "aws_ssm_document" "apply_ansible" {
  name            = "${var.project_name}-${var.environment}-apply-ansible"
  document_type   = "Command"
  document_format = "YAML"

  content = <<DOC
schemaVersion: '2.2'
description: Apply the approved Ansible hardening bundle from S3.
parameters:
  BundleKey:
    type: String
    default: "${var.ansible_bundle_key_prefix}bundle.tar.gz"
mainSteps:
  - action: aws:runShellScript
    name: applyAnsible
    inputs:
      runCommand:
        - "set -euo pipefail"
        - "mkdir -p /opt/capstone/ansible"
        - "aws s3 cp s3://${aws_s3_bucket.ansible.bucket}/{{ BundleKey }} /opt/capstone/ansible/bundle.tar.gz"
        - "tar -xzf /opt/capstone/ansible/bundle.tar.gz -C /opt/capstone/ansible"
        - "ansible-playbook /opt/capstone/ansible/playbooks/base-tasks.yml"
DOC
}

resource "aws_ssm_association" "web" {
  name = aws_ssm_document.apply_ansible.name

  targets {
    key    = "tag:Role"
    values = ["web"]
  }

  schedule_expression = "rate(7 days)"
}

resource "aws_ssm_association" "app" {
  name = aws_ssm_document.apply_ansible.name

  targets {
    key    = "tag:Role"
    values = ["app"]
  }

  schedule_expression = "rate(7 days)"
}
