variable "project_name" {
  description = "Short, lowercase project identifier used as the base for AWS resource names."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID from the network module — flow logs attach here."
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the project KMS key (from the security module) — used to encrypt the flow logs CloudWatch log group."
  type        = string
}