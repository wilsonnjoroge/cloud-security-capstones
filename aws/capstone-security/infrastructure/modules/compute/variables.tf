# -----------------------------------------------------------------------------
# Compute Module Variables
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

variable "web_subnet_ids" {
  description = "Private subnet IDs used by the web tier."
  type        = list(string)

  validation {
    condition     = length(var.web_subnet_ids) == 2 && length(distinct(var.web_subnet_ids)) == 2 && alltrue([for id in var.web_subnet_ids : can(regex("^subnet-[0-9a-f]+$", id))])
    error_message = "web_subnet_ids must contain exactly two subnet IDs."
  }
}

variable "app_subnet_ids" {
  description = "Private subnet IDs used by the application tier."
  type        = list(string)

  validation {
    condition     = length(var.app_subnet_ids) == 2 && length(distinct(var.app_subnet_ids)) == 2 && alltrue([for id in var.app_subnet_ids : can(regex("^subnet-[0-9a-f]+$", id))])
    error_message = "app_subnet_ids must contain exactly two subnet IDs."
  }
}

variable "web_security_group_id" {
  description = "Security group ID assigned to web-tier instances."
  type        = string

  validation {
    condition     = can(regex("^sg-[0-9a-f]+$", var.web_security_group_id))
    error_message = "web_security_group_id must be a valid AWS security group ID."
  }
}

variable "app_security_group_id" {
  description = "Security group ID assigned to application-tier instances."
  type        = string

  validation {
    condition     = can(regex("^sg-[0-9a-f]+$", var.app_security_group_id))
    error_message = "app_security_group_id must be a valid AWS security group ID."
  }
}

variable "web_instance_profile_name" {
  description = "IAM instance profile used by web-tier EC2 instances."
  type        = string
  validation {
    condition     = length(trimspace(var.web_instance_profile_name)) > 0
    error_message = "web_instance_profile_name must not be empty."
  }
}

variable "app_instance_profile_name" {
  description = "IAM instance profile used by application-tier EC2 instances."
  type        = string
  validation {
    condition     = length(trimspace(var.app_instance_profile_name)) > 0
    error_message = "app_instance_profile_name must not be empty."
  }
}

variable "ebs_kms_key_arn" {
  description = "Customer-managed KMS key ARN used for EC2 root EBS encryption."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[0-9a-f-]+$", var.ebs_kms_key_arn))
    error_message = "ebs_kms_key_arn must be a valid AWS KMS key ARN."
  }
}

variable "ansible_kms_key_arn" {
  description = "Customer-managed KMS key ARN used to encrypt the Ansible bundle."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[0-9a-f-]+$", var.ansible_kms_key_arn))
    error_message = "ansible_kms_key_arn must be a valid AWS KMS key ARN."
  }
}

variable "web_target_group_arn" {
  description = "Public ALB target group ARN for the web tier."
  type        = string
  validation {
    condition     = can(regex("^arn:aws(-us-gov|-cn)?:elasticloadbalancing:[a-z0-9-]+:[0-9]{12}:targetgroup/", var.web_target_group_arn))
    error_message = "web_target_group_arn must be a valid ELB target group ARN."
  }
}

variable "app_target_group_arn" {
  description = "Internal ALB target group ARN for the app tier."
  type        = string
  validation {
    condition     = can(regex("^arn:aws(-us-gov|-cn)?:elasticloadbalancing:[a-z0-9-]+:[0-9]{12}:targetgroup/", var.app_target_group_arn))
    error_message = "app_target_group_arn must be a valid ELB target group ARN."
  }
}

variable "web_ami_id" {
  description = "AMI ID used for web-tier EC2 instances."
  type        = string
  default     = null

  validation {
    condition     = var.web_ami_id == null || can(regex("^ami-[0-9a-f]+$", var.web_ami_id))
    error_message = "web_ami_id must be null or a valid AWS AMI ID."
  }
}

variable "app_ami_id" {
  description = "AMI ID used for application-tier EC2 instances."
  type        = string
  default     = null

  validation {
    condition     = var.app_ami_id == null || can(regex("^ami-[0-9a-f]+$", var.app_ami_id))
    error_message = "app_ami_id must be null or a valid AWS AMI ID."
  }
}

variable "web_instance_type" {
  description = "EC2 instance type for the web tier."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z0-9]+\\.[a-z0-9]+$", var.web_instance_type))
    error_message = "web_instance_type must look like a valid EC2 instance type, for example t3.micro."
  }
}

variable "app_instance_type" {
  description = "EC2 instance type for the application tier."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z0-9]+\\.[a-z0-9]+$", var.app_instance_type))
    error_message = "app_instance_type must look like a valid EC2 instance type, for example t3.micro."
  }
}

variable "web_min_size" {
  description = "Minimum number of web-tier instances."
  type        = number
  default     = 2

  validation {
    condition     = var.web_min_size >= 2
    error_message = "web_min_size must be at least 2 for two-AZ high availability."
  }
}

variable "web_max_size" {
  description = "Maximum number of web-tier instances."
  type        = number
  default     = 4

  validation {
    condition     = var.web_max_size >= var.web_min_size
    error_message = "web_max_size must be greater than or equal to web_min_size."
  }
}

variable "app_min_size" {
  description = "Minimum number of application-tier instances."
  type        = number
  default     = 2

  validation {
    condition     = var.app_min_size >= 2
    error_message = "app_min_size must be at least 2 for two-AZ high availability."
  }
}

variable "app_max_size" {
  description = "Maximum number of application-tier instances."
  type        = number
  default     = 4

  validation {
    condition     = var.app_max_size >= var.app_min_size
    error_message = "app_max_size must be greater than or equal to app_min_size."
  }
}

variable "web_target_cpu" {
  description = "Target average CPU utilization for web ASG target tracking."
  type        = number
  default     = 60

  validation {
    condition     = var.web_target_cpu >= 20 && var.web_target_cpu <= 80
    error_message = "web_target_cpu must be between 20 and 80 percent."
  }
}

variable "app_target_cpu" {
  description = "Target average CPU utilization for app ASG target tracking."
  type        = number
  default     = 60

  validation {
    condition     = var.app_target_cpu >= 20 && var.app_target_cpu <= 80
    error_message = "app_target_cpu must be between 20 and 80 percent."
  }
}

variable "ansible_bundle_key_prefix" {
  description = "S3 prefix containing the versioned Ansible bundle."
  type        = string

  validation {
    condition     = length(trimspace(var.ansible_bundle_key_prefix)) > 0 && !startswith(var.ansible_bundle_key_prefix, "/")
    error_message = "ansible_bundle_key_prefix must be non-empty and must not start with '/'."
  }
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB for both tiers."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8
    error_message = "root_volume_size must be at least 8 GiB."
  }
}
