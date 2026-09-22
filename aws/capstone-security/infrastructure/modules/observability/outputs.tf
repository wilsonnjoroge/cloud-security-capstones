output "flow_log_id" {
  description = "VPC Flow Log ID."
  value       = aws_flow_log.vpc.id
}

output "flow_log_log_group_name" {
  description = "CloudWatch Log Group receiving VPC Flow Logs."
  value       = aws_cloudwatch_log_group.vpc_flow_logs.name
}

output "flow_log_delivery_role_arn" {
  description = "VPC Flow Logs delivery role ARN."
  value       = aws_iam_role.flow_logs.arn
}
