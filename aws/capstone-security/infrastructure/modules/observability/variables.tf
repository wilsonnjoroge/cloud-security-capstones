# -----------------------------------------------------------------------------
# Observability Module Variables
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Short, lowercase project identifier used as the base for AWS resource names."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "project_name must be 3-21 characters, start with a lowercase letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment identifier."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.environment))
    error_message = "environment must be 2-16 characters, start with a lowercase letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vpc_id" {
  description = "VPC ID whose traffic is logged."
  type        = string
  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must be a valid AWS VPC ID."
  }
}

variable "flow_logs_kms_key_arn" {
  description = "Dedicated KMS key ARN for VPC Flow Logs CloudWatch Logs encryption."
  type        = string
  validation {
    condition     = can(regex("^arn:aws(-us-gov|-cn)?:kms:[a-z0-9-]+:[0-9]{12}:key/[0-9a-f-]+$", var.flow_logs_kms_key_arn))
    error_message = "flow_logs_kms_key_arn must be a valid KMS key ARN."
  }
}

variable "flow_log_retention_days" {
  description = "CloudWatch Logs retention period for VPC Flow Logs."
  type        = number
  default     = 30
  validation {
    condition     = var.flow_log_retention_days == 30
    error_message = "flow_log_retention_days must be 30 days for the approved capstone baseline."
  }
}
