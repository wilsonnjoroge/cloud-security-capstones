# -----------------------------------------------------------------------------
# Network Module Variables
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

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "Exactly two distinct Availability Zones used by the environment."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2 && alltrue([for az in var.availability_zones : can(regex("^[a-z]{2}-[a-z0-9-]+-[0-9][a-z]$", az))])
    error_message = "availability_zones must contain exactly two distinct AWS Availability Zone names."
  }
}

variable "public_subnet_cidrs" {
  description = "Two public subnet CIDRs, one per Availability Zone."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == 2 && length(distinct(var.public_subnet_cidrs)) == 2 && alltrue([for cidr in var.public_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "public_subnet_cidrs must contain exactly two distinct valid IPv4 CIDRs."
  }
}

variable "web_subnet_cidrs" {
  description = "Two private web-tier subnet CIDRs, one per Availability Zone."
  type        = list(string)

  validation {
    condition     = length(var.web_subnet_cidrs) == 2 && length(distinct(var.web_subnet_cidrs)) == 2 && alltrue([for cidr in var.web_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "web_subnet_cidrs must contain exactly two distinct valid IPv4 CIDRs."
  }
}

variable "app_subnet_cidrs" {
  description = "Two private application-tier subnet CIDRs, one per Availability Zone."
  type        = list(string)

  validation {
    condition     = length(var.app_subnet_cidrs) == 2 && length(distinct(var.app_subnet_cidrs)) == 2 && alltrue([for cidr in var.app_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "app_subnet_cidrs must contain exactly two distinct valid IPv4 CIDRs."
  }
}

variable "db_subnet_cidrs" {
  description = "Two isolated data-tier subnet CIDRs, one per Availability Zone."
  type        = list(string)

  validation {
    condition     = length(var.db_subnet_cidrs) == 2 && length(distinct(var.db_subnet_cidrs)) == 2 && alltrue([for cidr in var.db_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "db_subnet_cidrs must contain exactly two distinct valid IPv4 CIDRs."
  }
}

variable "enable_nat_gateway" {
  description = "Create one NAT Gateway per Availability Zone for private web and app subnets."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Compatibility input retained for environment wiring; Flow Logs are owned by the observability module."
  type        = bool
  default     = true
}

