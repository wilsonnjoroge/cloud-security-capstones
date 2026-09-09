# -----------------------------------------------------------------------------
# Security Group Outputs
# -----------------------------------------------------------------------------

output "public_alb_security_group_id" {
  description = "Security group ID for the public-facing ALB."
  value       = aws_security_group.public_alb.id
}

output "web_security_group_id" {
  description = "Security group ID for the private web tier."
  value       = aws_security_group.web.id
}

output "internal_alb_security_group_id" {
  description = "Security group ID for the internal ALB."
  value       = aws_security_group.internal_alb.id
}

output "app_security_group_id" {
  description = "Security group ID for the private application tier."
  value       = aws_security_group.app.id
}

output "rds_security_group_id" {
  description = "Security group ID for the RDS database."
  value       = aws_security_group.rds.id
}

output "redis_security_group_id" {
  description = "Security group ID for Redis/Valkey."
  value       = aws_security_group.redis.id
}

# -----------------------------------------------------------------------------
# IAM Outputs
# -----------------------------------------------------------------------------

output "ec2_ssm_role_name" {
  description = "Name of the EC2 Systems Manager IAM role."
  value = (
    var.enable_ssm_instance_role
    ? aws_iam_role.ec2_ssm[0].name
    : null
  )
}

output "ec2_ssm_role_arn" {
  description = "ARN of the EC2 Systems Manager IAM role."
  value = (
    var.enable_ssm_instance_role
    ? aws_iam_role.ec2_ssm[0].arn
    : null
  )
}

output "ec2_instance_profile_name" {
  description = "Name of the EC2 instance profile used by SSM-managed instances."
  value = (
    var.enable_ssm_instance_role
    ? aws_iam_instance_profile.ec2_ssm[0].name
    : null
  )
}

output "ec2_instance_profile_arn" {
  description = "ARN of the EC2 instance profile."
  value = (
    var.enable_ssm_instance_role
    ? aws_iam_instance_profile.ec2_ssm[0].arn
    : null
  )
}

# -----------------------------------------------------------------------------
# KMS Outputs
# -----------------------------------------------------------------------------

output "kms_key_id" {
  description = "ID of the customer-managed KMS key."
  value       = aws_kms_key.capstone.key_id
}

output "kms_key_arn" {
  description = "ARN of the customer-managed KMS key."
  value       = aws_kms_key.capstone.arn
}

output "kms_alias_name" {
  description = "Alias of the customer-managed KMS key."
  value       = aws_kms_alias.capstone.name
}