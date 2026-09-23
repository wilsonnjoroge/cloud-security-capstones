# -----------------------------------------------------------------------------
# Edge Module Variables
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

variable "name_prefix" {
  description = "Optional short name prefix override used when AWS resource name limits require it."
  type        = string
  default     = null

  validation {
    condition     = var.name_prefix == null || can(regex("^[a-z][a-z0-9-]{2,20}$", var.name_prefix))
    error_message = "name_prefix must be null or 3-21 characters using lowercase letters, numbers, and hyphens."
  }
}

variable "public_subnet_ids" {
  description = "Exactly two public subnet IDs for the internet-facing ALB."
  type        = list(string)
  validation {
    condition     = length(var.public_subnet_ids) == 2 && length(distinct(var.public_subnet_ids)) == 2 && alltrue([for id in var.public_subnet_ids : can(regex("^subnet-[0-9a-f]+$", id))])
    error_message = "public_subnet_ids must contain exactly two distinct valid subnet IDs."
  }
}

variable "web_subnet_ids" {
  description = "Exactly two private web subnet IDs used by the internal ALB."
  type        = list(string)
  validation {
    condition     = length(var.web_subnet_ids) == 2 && length(distinct(var.web_subnet_ids)) == 2 && alltrue([for id in var.web_subnet_ids : can(regex("^subnet-[0-9a-f]+$", id))])
    error_message = "web_subnet_ids must contain exactly two distinct valid subnet IDs."
  }
}

variable "public_alb_security_group_id" {
  description = "Security group ID for the public ALB."
  type        = string
  validation {
    condition     = can(regex("^sg-[0-9a-f]+$", var.public_alb_security_group_id))
    error_message = "public_alb_security_group_id must be a valid AWS security group ID."
  }
}

variable "internal_alb_security_group_id" {
  description = "Security group ID for the internal ALB."
  type        = string
  validation {
    condition     = can(regex("^sg-[0-9a-f]+$", var.internal_alb_security_group_id))
    error_message = "internal_alb_security_group_id must be a valid AWS security group ID."
  }
}

variable "web_listen_port" {
  description = "TLS target port used by the web tier."
  type        = number
  default     = 8443
  validation {
    condition     = var.web_listen_port >= 1024 && var.web_listen_port <= 65535
    error_message = "web_listen_port must be between 1024 and 65535."
  }
}

variable "app_listen_port" {
  description = "TLS target port used by the app tier."
  type        = number
  default     = 8080
  validation {
    condition     = var.app_listen_port >= 1024 && var.app_listen_port <= 65535
    error_message = "app_listen_port must be between 1024 and 65535."
  }
}

variable "internal_alb_certificate_arn" {
  description = "ACM certificate ARN for the mandatory internal ALB HTTPS listener."
  type        = string

  validation {
    condition     = can(regex("^arn:aws(-us-gov|-cn)?:acm:[a-z0-9-]+:[0-9]{12}:certificate/[0-9a-f-]+$", var.internal_alb_certificate_arn))
    error_message = "internal_alb_certificate_arn must be a valid ACM certificate ARN."
  }
}
