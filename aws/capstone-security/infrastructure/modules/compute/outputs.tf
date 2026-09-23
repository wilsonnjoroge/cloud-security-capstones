output "web_launch_template_id" {
  description = "Web launch template ID."
  value       = aws_launch_template.web.id
}

output "app_launch_template_id" {
  description = "App launch template ID."
  value       = aws_launch_template.app.id
}

output "web_asg_name" {
  description = "Web Auto Scaling Group name."
  value       = aws_autoscaling_group.web.name
}

output "app_asg_name" {
  description = "App Auto Scaling Group name."
  value       = aws_autoscaling_group.app.name
}

output "ansible_bundle_bucket_name" {
  description = "Private, versioned Ansible bundle bucket name."
  value       = aws_s3_bucket.ansible.bucket
}

output "ansible_bundle_bucket_arn" {
  description = "Private, versioned Ansible bundle bucket ARN."
  value       = aws_s3_bucket.ansible.arn
}

output "ansible_ssm_document_name" {
  description = "SSM document used for Ansible application."
  value       = aws_ssm_document.apply_ansible.name
}
