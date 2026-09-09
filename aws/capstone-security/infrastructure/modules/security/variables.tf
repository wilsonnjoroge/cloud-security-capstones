# -----------------------------------------------------------------------------
# Security Module Variables
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Short, lowercase project identifier used as the base for AWS resource names."
  type        = string

  validation {
    condition = can(regex(
      "^[a-z][a-z0-9-]{2,20}$",
      var.project_name
    ))

    error_message = "project_name must be 3-21 characters, start with a lowercase letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vpc_id" {
  description = "ID of the VPC where security groups and other security resources are created."
  type        = string

  validation {
    condition     = length(trimspace(var.vpc_id)) > 0
    error_message = "vpc_id must not be empty."
  }
}

variable "vpc_cidr" {
  description = "CIDR block of the capstone VPC."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "app_listen_port" {
  description = "TCP port exposed by application instances to the internal load balancer."
  type        = number
  default     = 8080

  validation {
    condition     = var.app_listen_port >= 1024 && var.app_listen_port <= 65535
    error_message = "app_listen_port must be between 1024 and 65535."
  }
}

variable "web_listen_port" {
  description = "TCP port exposed by web instances to the public-facing load balancer."
  type        = number
  default     = 8443

  validation {
    condition     = var.web_listen_port >= 1024 && var.web_listen_port <= 65535
    error_message = "web_listen_port must be between 1024 and 65535."
  }
}

variable "db_port" {
  description = "TCP port used by the RDS database."
  type        = number
  default     = 3306

  validation {
    condition     = var.db_port >= 1 && var.db_port <= 65535
    error_message = "db_port must be between 1 and 65535."
  }
}

variable "redis_port" {
  description = "TCP port used by the Redis/Valkey cache."
  type        = number
  default     = 6379

  validation {
    condition     = var.redis_port >= 1 && var.redis_port <= 65535
    error_message = "redis_port must be between 1 and 65535."
  }
}

variable "enable_ssm_instance_role" {
  description = "Whether to create the EC2 IAM role and instance profile used by AWS Systems Manager."
  type        = bool
  default     = true
}

variable "kms_deletion_window_in_days" {
  description = "Number of days before a KMS key is permanently deleted after key deletion is scheduled."
  type        = number
  default     = 30

  validation {
    condition = (
      var.kms_deletion_window_in_days >= 7 &&
      var.kms_deletion_window_in_days <= 30
    )

    error_message = "kms_deletion_window_in_days must be between 7 and 30 days."
  }
}

variable "ansible_bundle_bucket_arn" {
  description = "ARN of the S3 bucket containing Ansible deployment bundles."
  type        = string

  validation {
    condition = can(regex(
      "^arn:aws:s3:::[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$",
      var.ansible_bundle_bucket_arn
    ))

    error_message = "ansible_bundle_bucket_arn must be a valid S3 bucket ARN."
  }
}

variable "application_secret_arns" {
  description = "ARNs of Secrets Manager secrets that the application workload is allowed to read."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for arn in var.application_secret_arns :
      can(regex("^arn:aws:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:.+$", arn))
    ])

    error_message = "Every application_secret_arns value must be a valid Secrets Manager secret ARN."
  }
}