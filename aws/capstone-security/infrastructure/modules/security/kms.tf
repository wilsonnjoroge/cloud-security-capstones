# -----------------------------------------------------------------------------
# KMS Key
# -----------------------------------------------------------------------------
# Customer-managed key used for encryption of protected capstone resources.
#
# The key policy intentionally grants account-root administration rather than
# granting broad service permissions to arbitrary principals. Individual AWS
# services can use the key through their resource-level encryption settings
# and service integrations.

resource "aws_kms_key" "capstone" {
  description             = "Customer managed encryption key for ${var.project_name}"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "EnableIAMPolicies"
        Effect = "Allow"

        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }

        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-kms-key"
    Project = var.project_name
    Purpose = "encryption"
  }
}

# -----------------------------------------------------------------------------
# KMS Alias
# -----------------------------------------------------------------------------

resource "aws_kms_alias" "capstone" {
  name          = "alias/${var.project_name}"
  target_key_id = aws_kms_key.capstone.key_id
}

# -----------------------------------------------------------------------------
# Current AWS Account
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}