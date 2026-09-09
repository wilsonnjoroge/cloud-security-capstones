
output "flow_log_id" {
  description = "ID of the VPC flow log."
  value       = aws_flow_log.capstone.id
}

output "flow_log_group_name" {
  description = "Name of the CloudWatch log group holding flow log data — reference this for dashboards/alarms/log-insights queries."
  value       = aws_cloudwatch_log_group.vpc_flow_logs.name
}

output "flow_log_group_arn" {
  description = "ARN of the flow logs CloudWatch log group."
  value       = aws_cloudwatch_log_group.vpc_flow_logs.arn
}