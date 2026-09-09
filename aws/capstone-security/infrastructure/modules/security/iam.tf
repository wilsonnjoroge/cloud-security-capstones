# -----------------------------------------------------------------------------
# EC2 Systems Manager IAM Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "ec2_ssm" {
  count = var.enable_ssm_instance_role ? 1 : 0

  name = "${var.project_name}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "EC2AssumeRole"
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-ec2-ssm-role"
    Project = var.project_name
    Purpose = "ec2-management"
  }
}

# -----------------------------------------------------------------------------
# AWS Systems Manager Core Permissions
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  count = var.enable_ssm_instance_role ? 1 : 0

  role       = aws_iam_role.ec2_ssm[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# -----------------------------------------------------------------------------
# Ansible Bundle Access
# -----------------------------------------------------------------------------
# EC2 instances retrieve Ansible deployment/configuration bundles from the
# dedicated S3 bucket.
#
# Access is restricted to the specific bucket rather than granting general
# S3 permissions.

resource "aws_iam_role_policy" "ansible_bundle_access" {
  count = var.enable_ssm_instance_role ? 1 : 0

  name = "${var.project_name}-ansible-bundle-access"
  role = aws_iam_role.ec2_ssm[0].id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ListAnsibleBundleBucket"
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = var.ansible_bundle_bucket_arn
      },
      {
        Sid    = "ReadAnsibleBundles"
        Effect = "Allow"

        Action = [
          "s3:GetObject"
        ]

        Resource = "${var.ansible_bundle_bucket_arn}/*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# EC2 Instance Profile
# -----------------------------------------------------------------------------

resource "aws_iam_instance_profile" "ec2_ssm" {
  count = var.enable_ssm_instance_role ? 1 : 0

  name = "${var.project_name}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm[0].name

  tags = {
    Name    = "${var.project_name}-ec2-ssm-profile"
    Project = var.project_name
    Purpose = "ec2-instance-profile"
  }
}

# -----------------------------------------------------------------------------
# Application Workload IAM Role
# -----------------------------------------------------------------------------
# This role is deliberately separate from the base SSM role.
#
# The application should receive only the permissions it actually requires.
# Secrets Manager access is scoped to explicitly supplied secret ARNs.

resource "aws_iam_role" "application" {
  name = "${var.project_name}-application-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "EC2AssumeRole"
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-application-role"
    Project = var.project_name
    Purpose = "application-workload"
  }
}

# -----------------------------------------------------------------------------
# Application Secrets Manager Access
# -----------------------------------------------------------------------------
# No wildcard Secrets Manager access.
#
# The environment passes the exact secret ARNs that the application is
# permitted to retrieve.

resource "aws_iam_role_policy" "application_secrets" {
  count = length(var.application_secret_arns) > 0 ? 1 : 0

  name = "${var.project_name}-application-secrets"
  role = aws_iam_role.application.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ReadApplicationSecrets"
        Effect = "Allow"

        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue"
        ]

        Resource = var.application_secret_arns
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Application Instance Profile
# -----------------------------------------------------------------------------

resource "aws_iam_instance_profile" "application" {
  name = "${var.project_name}-application-profile"
  role = aws_iam_role.application.name

  tags = {
    Name    = "${var.project_name}-application-profile"
    Project = var.project_name
    Purpose = "application-instance-profile"
  }
}