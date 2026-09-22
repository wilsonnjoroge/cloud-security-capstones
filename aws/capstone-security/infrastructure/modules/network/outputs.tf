output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR."
  value       = aws_vpc.this.cidr_block
}

output "availability_zones" {
  description = "Availability Zones used by the environment."
  value       = var.availability_zones
}

output "public_subnet_ids" {
  description = "Public subnet IDs in AZ order."
  value       = [for index in range(2) : aws_subnet.public[tostring(index)].id]
}

output "web_subnet_ids" {
  description = "Web subnet IDs in AZ order."
  value       = [for index in range(2) : aws_subnet.web[tostring(index)].id]
}

output "app_subnet_ids" {
  description = "App subnet IDs in AZ order."
  value       = [for index in range(2) : aws_subnet.app[tostring(index)].id]
}

output "db_subnet_ids" {
  description = "DB subnet IDs in AZ order."
  value       = [for index in range(2) : aws_subnet.db[tostring(index)].id]
}

output "db_subnet_group_name" {
  description = "RDS DB subnet group name."
  value       = aws_db_subnet_group.this.name
}

output "cache_subnet_group_name" {
  description = "ElastiCache subnet group name."
  value       = aws_elasticache_subnet_group.this.name
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs by Availability Zone index."
  value       = { for key, nat in aws_nat_gateway.this : key => nat.id }
}

output "vpc_endpoint_ids" {
  description = "VPC endpoint IDs."
  value = merge(
    { s3 = aws_vpc_endpoint.s3.id },
    { for key, endpoint in aws_vpc_endpoint.interface : key => endpoint.id }
  )
}

output "vpc_endpoint_security_group_id" {
  description = "Dedicated security group ID used by interface VPC endpoints."
  value       = aws_security_group.vpc_endpoints.id
}
