# -----------------------------------------------------------------------------
# Core VPC outputs
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the capstone VPC."
  value       = aws_vpc.capstone.id
}

output "vpc_cidr" {
  description = "CIDR block of the capstone VPC."
  value       = var.vpc_cidr
}

output "internet_gateway_id" {
  description = "ID of the VPC Internet Gateway."
  value       = aws_internet_gateway.capstone.id
}

# -----------------------------------------------------------------------------
# Subnet outputs
# -----------------------------------------------------------------------------

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "web_subnet_ids" {
  description = "IDs of the private web-tier subnets."
  value       = aws_subnet.web[*].id
}

output "app_subnet_ids" {
  description = "IDs of the private application-tier subnets."
  value       = aws_subnet.app[*].id
}

output "db_subnet_ids" {
  description = "IDs of the isolated database subnets."
  value       = aws_subnet.db[*].id
}

output "public_subnet_cidrs" {
  description = "CIDRs of the public subnets."
  value       = var.public_subnet_cidrs
}

output "web_subnet_cidrs" {
  description = "CIDRs of the private web-tier subnets."
  value       = var.web_subnet_cidrs
}

output "app_subnet_cidrs" {
  description = "CIDRs of the private application-tier subnets."
  value       = var.app_subnet_cidrs
}

output "db_subnet_cidrs" {
  description = "CIDRs of the isolated database subnets."
  value       = var.db_subnet_cidrs
}

# -----------------------------------------------------------------------------
# Route table outputs
# -----------------------------------------------------------------------------

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "web_route_table_ids" {
  description = "IDs of the web-tier route tables, one per Availability Zone."
  value       = aws_route_table.web[*].id
}

output "app_route_table_ids" {
  description = "IDs of the application-tier route tables, one per Availability Zone."
  value       = aws_route_table.app[*].id
}

output "db_route_table_id" {
  description = "ID of the isolated database route table."
  value       = aws_route_table.db.id
}

# -----------------------------------------------------------------------------
# NAT outputs
# -----------------------------------------------------------------------------

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways, one per Availability Zone."
  value       = aws_nat_gateway.nat[*].id
}

output "nat_eip_addresses" {
  description = "Elastic IP addresses assigned to the NAT Gateways."
  value       = aws_eip.nat[*].public_ip
}

# -----------------------------------------------------------------------------
# Data subnet group outputs
# -----------------------------------------------------------------------------

output "rds_subnet_group_name" {
  description = "Name of the RDS DB subnet group."
  value       = aws_db_subnet_group.capstone.name
}

output "elasticache_subnet_group_name" {
  description = "Name of the ElastiCache subnet group."
  value       = aws_elasticache_subnet_group.capstone.name
}

# -----------------------------------------------------------------------------
# VPC endpoint outputs
# -----------------------------------------------------------------------------

output "vpc_endpoint_security_group_id" {
  description = "Security group ID attached to interface VPC endpoints."
  value       = aws_security_group.vpc_endpoints.id
}

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 Gateway VPC endpoint."
  value       = aws_vpc_endpoint.s3.id
}

output "ssm_vpc_endpoint_id" {
  description = "ID of the Systems Manager VPC endpoint."
  value       = aws_vpc_endpoint.ssm.id
}

output "ssmmessages_vpc_endpoint_id" {
  description = "ID of the SSM Messages VPC endpoint."
  value       = aws_vpc_endpoint.ssmmessages.id
}

output "ec2messages_vpc_endpoint_id" {
  description = "ID of the EC2 Messages VPC endpoint."
  value       = aws_vpc_endpoint.ec2messages.id
}

output "secretsmanager_vpc_endpoint_id" {
  description = "ID of the Secrets Manager VPC endpoint."
  value       = aws_vpc_endpoint.secretsmanager.id
}