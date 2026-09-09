# -----------------------------------------------------------------------------
# Web Tier Outputs
# -----------------------------------------------------------------------------

output "web_instance_ids" {
  description = "IDs of web-tier EC2 instances."
  value       = aws_instance.web[*].id
}

output "web_private_ips" {
  description = "Private IP addresses of web-tier EC2 instances."
  value       = aws_instance.web[*].private_ip
}

output "web_instance_names" {
  description = "Names of web-tier EC2 instances."
  value       = aws_instance.web[*].tags["Name"]
}

# -----------------------------------------------------------------------------
# Application Tier Outputs
# -----------------------------------------------------------------------------

output "app_instance_ids" {
  description = "IDs of application-tier EC2 instances."
  value       = aws_instance.app[*].id
}

output "app_private_ips" {
  description = "Private IP addresses of application-tier EC2 instances."
  value       = aws_instance.app[*].private_ip
}

output "app_instance_names" {
  description = "Names of application-tier EC2 instances."
  value       = aws_instance.app[*].tags["Name"]
}

# -----------------------------------------------------------------------------
# Ansible Outputs
# -----------------------------------------------------------------------------

output "ansible_inventory_path" {
  description = "Path to the Terraform-generated Ansible inventory."
  value       = local_file.ansible_inventory.filename
}