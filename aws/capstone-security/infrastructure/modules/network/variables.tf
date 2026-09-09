# -----------------------------------------------------------------------------
# Network Module Variables
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Short, lowercase project identifier used as the base for AWS resource names."
  type        = string
  default     = "capstone"

  validation {
    condition = can(regex(
      "^[a-z][a-z0-9-]{2,20}$",
      var.project_name
    ))

    error_message = "project_name must be 3-21 characters, start with a lowercase letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the capstone VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "Two Availability Zones used by the capstone. Each tier has one subnet per AZ."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition = (
      length(var.availability_zones) == 2 &&
      length(distinct(var.availability_zones)) == 2 &&
      alltrue([
        for az in var.availability_zones :
        can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+[a-z]$", az))
      ])
    )

    error_message = "availability_zones must contain exactly two unique valid AWS Availability Zones."
  }
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs used for NAT Gateway placement, one per Availability Zone."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]

  validation {
    condition = (
      length(var.public_subnet_cidrs) == 2 &&
      length(distinct(var.public_subnet_cidrs)) == 2 &&
      alltrue([
        for cidr in var.public_subnet_cidrs :
        can(cidrhost(cidr, 0))
      ])
    )

    error_message = "public_subnet_cidrs must contain exactly two unique valid IPv4 CIDRs."
  }
}

variable "web_subnet_cidrs" {
  description = "Private web-tier subnet CIDRs, one per Availability Zone."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]

  validation {
    condition = (
      length(var.web_subnet_cidrs) == 2 &&
      length(distinct(var.web_subnet_cidrs)) == 2 &&
      alltrue([
        for cidr in var.web_subnet_cidrs :
        can(cidrhost(cidr, 0))
      ])
    )

    error_message = "web_subnet_cidrs must contain exactly two unique valid IPv4 CIDRs."
  }
}

variable "app_subnet_cidrs" {
  description = "Private application-tier subnet CIDRs, one per Availability Zone."
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]

  validation {
    condition = (
      length(var.app_subnet_cidrs) == 2 &&
      length(distinct(var.app_subnet_cidrs)) == 2 &&
      alltrue([
        for cidr in var.app_subnet_cidrs :
        can(cidrhost(cidr, 0))
      ])
    )

    error_message = "app_subnet_cidrs must contain exactly two unique valid IPv4 CIDRs."
  }
}

variable "db_subnet_cidrs" {
  description = "Isolated database subnet CIDRs, one per Availability Zone. These subnets have no default route."
  type        = list(string)
  default     = ["10.0.30.0/24", "10.0.31.0/24"]

  validation {
    condition = (
      length(var.db_subnet_cidrs) == 2 &&
      length(distinct(var.db_subnet_cidrs)) == 2 &&
      alltrue([
        for cidr in var.db_subnet_cidrs :
        can(cidrhost(cidr, 0))
      ])
    )

    error_message = "db_subnet_cidrs must contain exactly two unique valid IPv4 CIDRs."
  }
}