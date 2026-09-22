variable "project_name" {
  description = "Project name used for resource naming and tags."
  type        = string
  default     = "capstone-security"
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = var.environment == "dev"
    error_message = "This environment configuration is for dev only."
  }
}

variable "aws_region" {
  description = "AWS region for the dev environment. CloudFront/WAF resources require us-east-1 in this design."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "The dev environment is currently pinned to us-east-1 because CloudFront-scoped WAF resources are managed there."
  }
}

variable "availability_zones" {
  description = "Two Availability Zones used by the capstone."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "Exactly two distinct Availability Zones are required."
  }
}

variable "vpc_cidr" {
  description = "CIDR for the capstone VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, one per Availability Zone."
  type        = list(string)
}

variable "web_subnet_cidrs" {
  description = "Private web-tier subnet CIDRs, one per Availability Zone."
  type        = list(string)
}

variable "app_subnet_cidrs" {
  description = "Private app-tier subnet CIDRs, one per Availability Zone."
  type        = list(string)
}

variable "db_subnet_cidrs" {
  description = "Isolated data-tier subnet CIDRs, one per Availability Zone."
  type        = list(string)
}

variable "web_listen_port" {
  description = "TLS listener port used by the web tier."
  type        = number
  default     = 8443
}

variable "app_listen_port" {
  description = "TLS listener port used by the app tier."
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "MySQL port."
  type        = number
  default     = 3306
}

variable "redis_port" {
  description = "Redis port."
  type        = number
  default     = 6379
}

variable "web_instance_type" {
  description = "EC2 instance type for the web tier."
  type        = string
  default     = "t3.micro"
}

variable "app_instance_type" {
  description = "EC2 instance type for the app tier."
  type        = string
  default     = "t3.micro"
}

variable "web_min_size" {
  description = "Minimum number of web instances."
  type        = number
  default     = 2
}

variable "web_max_size" {
  description = "Maximum number of web instances."
  type        = number
  default     = 4
}

variable "app_min_size" {
  description = "Minimum number of app instances."
  type        = number
  default     = 2
}

variable "app_max_size" {
  description = "Maximum number of app instances."
  type        = number
  default     = 4
}

variable "web_target_cpu" {
  description = "Target average CPU utilization for web ASG target tracking."
  type        = number
  default     = 60
}

variable "app_target_cpu" {
  description = "Target average CPU utilization for app ASG target tracking."
  type        = number
  default     = 60
}

variable "web_ami_id" {
  description = "Optional AMI ID for the web tier. Null lets the compute module resolve its approved Linux AMI."
  type        = string
  default     = null
}

variable "app_ami_id" {
  description = "Optional AMI ID for the app tier. Null lets the compute module resolve its approved Linux AMI."
  type        = string
  default     = null
}

variable "db_instance_class" {
  description = "RDS instance class for dev."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Initial RDS storage in GiB."
  type        = number
  default     = 20
}

variable "db_backup_retention_period" {
  description = "RDS automated backup retention in days."
  type        = number
  default     = 7
}

variable "cache_node_type" {
  description = "ElastiCache node type for dev."
  type        = string
  default     = "cache.t3.micro"
}

variable "cache_num_nodes" {
  description = "Number of Redis cache nodes. Two nodes provide one node per AZ for the capstone."
  type        = number
  default     = 2

  validation {
    condition     = var.cache_num_nodes == 2
    error_message = "The capstone dev environment requires two Redis nodes, one per AZ."
  }
}

variable "flow_log_retention_days" {
  description = "CloudWatch Logs retention for VPC Flow Logs."
  type        = number
  default     = 30
}

variable "enable_deletion_protection" {
  description = "Whether deletion protection is enabled for managed data resources."
  type        = bool
  default     = true
}

variable "enable_secrets_rotation" {
  description = "Automatic Secrets Manager rotation. Not implemented in the current capstone."
  type        = bool
  default     = false

  validation {
    condition     = var.enable_secrets_rotation == false
    error_message = "Automatic secret rotation is not implemented in the current capstone."
  }
}

variable "ansible_bundle_key_prefix" {
  description = "S3 key prefix used for the versioned Ansible bundle."
  type        = string
  default     = "ansible/"
}

variable "internal_alb_certificate_arn" {
  description = "ACM certificate ARN used by the mandatory internal ALB HTTPS listener."
  type        = string

  validation {
    condition     = can(regex("^arn:aws(-us-gov|-cn)?:acm:[a-z0-9-]+:[0-9]{12}:certificate/[0-9a-f-]+$", var.internal_alb_certificate_arn))
    error_message = "internal_alb_certificate_arn must be a valid ACM certificate ARN."
  }
}
