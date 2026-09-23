# -----------------------------------------------------------------------------
# Security Module Variables
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
  description = "VPC ID where the security boundaries are deployed."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must be a valid AWS VPC ID."
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR used by the dedicated endpoint security group."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "web_listen_port" {
  description = "TLS port exposed by the web tier to the public ALB."
  type        = number
  default     = 8443

  validation {
    condition     = var.web_listen_port >= 1024 && var.web_listen_port <= 65535
    error_message = "web_listen_port must be between 1024 and 65535."
  }
}

variable "app_listen_port" {
  description = "TLS port exposed by the app tier to the internal ALB."
  type        = number
  default     = 8080

  validation {
    condition     = var.app_listen_port >= 1024 && var.app_listen_port <= 65535
    error_message = "app_listen_port must be between 1024 and 65535."
  }
}

variable "db_port" {
  description = "MySQL port used by the application-to-RDS trust boundary."
  type        = number
  default     = 3306

  validation {
    condition     = var.db_port == 3306
    error_message = "db_port must remain 3306 for the approved MySQL architecture."
  }
}

variable "redis_port" {
  description = "Redis port used by the application-to-ElastiCache trust boundary."
  type        = number
  default     = 6379

  validation {
    condition     = var.redis_port == 6379
    error_message = "redis_port must remain 6379 for the approved Redis architecture."
  }
}

variable "vpc_endpoint_security_group_id" {
  description = "Security group ID for private AWS service interface endpoints."
  type        = string

  validation {
    condition     = can(regex("^sg-[0-9a-f]+$", var.vpc_endpoint_security_group_id))
    error_message = "vpc_endpoint_security_group_id must be a valid AWS security group ID."
  }
}
