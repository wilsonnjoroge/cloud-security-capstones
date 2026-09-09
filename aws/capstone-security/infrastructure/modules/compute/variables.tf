
# -----------------------------------------------------------------------------
# Compute Module Variables
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

# -----------------------------------------------------------------------------
# Network Inputs
# -----------------------------------------------------------------------------

variable "web_subnet_ids" {
  description = "Private subnet IDs used by the web tier."
  type        = list(string)

  validation {
    condition     = length(var.web_subnet_ids) == 2
    error_message = "web_subnet_ids must contain exactly two subnet IDs."
  }
}

variable "app_subnet_ids" {
  description = "Private subnet IDs used by the application tier."
  type        = list(string)

  validation {
    condition     = length(var.app_subnet_ids) == 2
    error_message = "app_subnet_ids must contain exactly two subnet IDs."
  }
}

# -----------------------------------------------------------------------------
# Security Inputs
# -----------------------------------------------------------------------------

variable "web_security_group_id" {
  description = "Security group ID assigned to web-tier instances."
  type        = string
}

variable "app_security_group_id" {
  description = "Security group ID assigned to application-tier instances."
  type        = string
}

variable "web_instance_profile_name" {
  description = "IAM instance profile used by web-tier EC2 instances."
  type        = string
}

variable "app_instance_profile_name" {
  description = "IAM instance profile used by application-tier EC2 instances."
  type        = string
}

# -----------------------------------------------------------------------------
# AMI / Instance Configuration
# -----------------------------------------------------------------------------

variable "web_ami_id" {
  description = "AMI ID used for web-tier EC2 instances."
  type        = string
}

variable "app_ami_id" {
  description = "AMI ID used for application-tier EC2 instances."
  type        = string
}

variable "web_instance_type" {
  description = "EC2 instance type for the web tier."
  type        = string
  default     = "t3.micro"
}

variable "app_instance_type" {
  description = "EC2 instance type for the application tier."
  type        = string
  default     = "t3.micro"
}

variable "web_root_volume_size" {
  description = "Root EBS volume size in GiB for web instances."
  type        = number
  default     = 20

  validation {
    condition     = var.web_root_volume_size >= 8
    error_message = "web_root_volume_size must be at least 8 GiB."
  }
}

variable "app_root_volume_size" {
  description = "Root EBS volume size in GiB for application instances."
  type        = number
  default     = 20

  validation {
    condition     = var.app_root_volume_size >= 8
    error_message = "app_root_volume_size must be at least 8 GiB."
  }
}

# -----------------------------------------------------------------------------
# Application Configuration
# -----------------------------------------------------------------------------

variable "app_listen_port" {
  description = "TCP port on which the application service listens."
  type        = number
  default     = 8080

  validation {
    condition     = var.app_listen_port >= 1024 && var.app_listen_port <= 65535
    error_message = "app_listen_port must be between 1024 and 65535."
  }
}

variable "web_listen_port" {
  description = "TCP port on which the web service listens."
  type        = number
  default     = 8443

  validation {
    condition     = var.web_listen_port >= 1024 && var.web_listen_port <= 65535
    error_message = "web_listen_port must be between 1024 and 65535."
  }
}

# -----------------------------------------------------------------------------
# Ansible Configuration
# -----------------------------------------------------------------------------

variable "ansible_bundle_bucket_name" {
  description = "S3 bucket containing Ansible deployment bundles."
  type        = string
}

variable "ansible_bundle_key" {
  description = "S3 object key containing the Ansible bundle for this deployment."
  type        = string
}

# -----------------------------------------------------------------------------
# Instance Count
# -----------------------------------------------------------------------------

variable "web_instance_count" {
  description = "Number of web-tier instances."
  type        = number
  default     = 2

  validation {
    condition     = var.web_instance_count >= 2
    error_message = "web_instance_count must be at least 2 for high availability."
  }
}

variable "app_instance_count" {
  description = "Number of application-tier instances."
  type        = number
  default     = 2

  validation {
    condition     = var.app_instance_count >= 2
    error_message = "app_instance_count must be at least 2 for high availability."
  }
}