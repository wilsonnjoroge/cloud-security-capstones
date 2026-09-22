# -----------------------------------------------------------------------------
# Data Module Variables
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

variable "db_subnet_group_name" {
  description = "Private isolated subnet group for RDS."
  type        = string
  validation {
    condition     = length(trimspace(var.db_subnet_group_name)) > 0
    error_message = "db_subnet_group_name must not be empty."
  }
}

variable "cache_subnet_group_name" {
  description = "Private isolated subnet group for ElastiCache."
  type        = string
  validation {
    condition     = length(trimspace(var.cache_subnet_group_name)) > 0
    error_message = "cache_subnet_group_name must not be empty."
  }
}

variable "rds_security_group_id" {
  description = "RDS security group ID."
  type        = string
  validation {
    condition     = can(regex("^sg-[0-9a-f]+$", var.rds_security_group_id))
    error_message = "rds_security_group_id must be a valid AWS security group ID."
  }
}

variable "redis_security_group_id" {
  description = "ElastiCache security group ID."
  type        = string
  validation {
    condition     = can(regex("^sg-[0-9a-f]+$", var.redis_security_group_id))
    error_message = "redis_security_group_id must be a valid AWS security group ID."
  }
}

variable "rds_kms_key_arn" {
  description = "Dedicated KMS key ARN for RDS storage encryption."
  type        = string
  validation {
    condition     = can(regex("^arn:aws(-us-gov|-cn)?:kms:[a-z0-9-]+:[0-9]{12}:key/[0-9a-f-]+$", var.rds_kms_key_arn))
    error_message = "rds_kms_key_arn must be a valid KMS key ARN."
  }
}

variable "elasticache_kms_key_arn" {
  description = "Dedicated KMS key ARN for ElastiCache at-rest encryption."
  type        = string
  validation {
    condition     = can(regex("^arn:aws(-us-gov|-cn)?:kms:[a-z0-9-]+:[0-9]{12}:key/[0-9a-f-]+$", var.elasticache_kms_key_arn))
    error_message = "elasticache_kms_key_arn must be a valid KMS key ARN."
  }
}

variable "secrets_kms_key_arn" {
  description = "Dedicated KMS key ARN for Secrets Manager."
  type        = string
  validation {
    condition     = can(regex("^arn:aws(-us-gov|-cn)?:kms:[a-z0-9-]+:[0-9]{12}:key/[0-9a-f-]+$", var.secrets_kms_key_arn))
    error_message = "secrets_kms_key_arn must be a valid KMS key ARN."
  }
}

variable "db_port" {
  description = "MySQL port."
  type        = number
  default     = 3306
  validation {
    condition     = var.db_port == 3306
    error_message = "db_port must remain 3306 for the approved MySQL architecture."
  }
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string

}

variable "db_allocated_storage" {
  description = "Initial RDS storage in GiB."
  type        = number
  default     = 20
  validation {
    condition     = var.db_allocated_storage >= 20
    error_message = "db_allocated_storage must be at least 20 GiB."
  }
}

variable "db_backup_retention_period" {
  description = "RDS automated backup retention in days."
  type        = number
  default     = 7
  validation {
    condition     = var.db_backup_retention_period == 7
    error_message = "db_backup_retention_period must be 7 days for the approved capstone baseline."
  }
}

variable "cache_node_type" {
  description = "ElastiCache node type."
  type        = string
}

variable "cache_num_nodes" {
  description = "Number of Redis cache nodes."
  type        = number
  default     = 2
  validation {
    condition     = var.cache_num_nodes == 2
    error_message = "cache_num_nodes must be 2 for the approved two-AZ baseline."
  }
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for RDS."
  type        = bool
  default     = true
  validation {
    condition     = var.enable_deletion_protection
    error_message = "Deletion protection must remain enabled for the approved data-tier baseline."
  }
}
