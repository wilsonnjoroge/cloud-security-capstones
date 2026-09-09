# -----------------------------------------------------------------------------
# VPC Endpoint Security Group
# -----------------------------------------------------------------------------
# Interface endpoints are reachable only from the private web and application
# subnet CIDRs. No internet-originated access is permitted.

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-vpc-endpoints-sg"
  description = "Security group for AWS interface VPC endpoints"
  vpc_id      = aws_vpc.capstone.id

  ingress {
    description = "HTTPS from private web tier"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = var.web_subnet_cidrs
  }

  ingress {
    description = "HTTPS from private application tier"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = var.app_subnet_cidrs
  }

  egress {
    description = "HTTPS response/service traffic within VPC"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name    = "${var.project_name}-vpc-endpoints-sg"
    Project = var.project_name
    Tier    = "network"
  }
}

# -----------------------------------------------------------------------------
# S3 Gateway Endpoint
# -----------------------------------------------------------------------------
# Gateway endpoints do not require ENIs or endpoint security groups.

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.capstone.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    aws_route_table.web[*].id,
    aws_route_table.app[*].id
  )

  tags = {
    Name    = "${var.project_name}-s3-endpoint"
    Project = var.project_name
    Service = "s3"
    Type    = "gateway"
  }
}

# -----------------------------------------------------------------------------
# SSM
# -----------------------------------------------------------------------------

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.capstone.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = concat(
    aws_subnet.web[*].id,
    aws_subnet.app[*].id
  )

  security_group_ids = [
    aws_security_group.vpc_endpoints.id
  ]

  tags = {
    Name    = "${var.project_name}-ssm-endpoint"
    Project = var.project_name
    Service = "ssm"
    Type    = "interface"
  }
}

# -----------------------------------------------------------------------------
# SSM Messages
# -----------------------------------------------------------------------------

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.capstone.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = concat(
    aws_subnet.web[*].id,
    aws_subnet.app[*].id
  )

  security_group_ids = [
    aws_security_group.vpc_endpoints.id
  ]

  tags = {
    Name    = "${var.project_name}-ssmmessages-endpoint"
    Project = var.project_name
    Service = "ssmmessages"
    Type    = "interface"
  }
}

# -----------------------------------------------------------------------------
# EC2 Messages
# -----------------------------------------------------------------------------

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.capstone.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = concat(
    aws_subnet.web[*].id,
    aws_subnet.app[*].id
  )

  security_group_ids = [
    aws_security_group.vpc_endpoints.id
  ]

  tags = {
    Name    = "${var.project_name}-ec2messages-endpoint"
    Project = var.project_name
    Service = "ec2messages"
    Type    = "interface"
  }
}

# -----------------------------------------------------------------------------
# Secrets Manager
# -----------------------------------------------------------------------------
# Secrets Manager is consumed primarily by application workloads, so its
# interface endpoints are placed only in the application tier.

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.capstone.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = aws_subnet.app[*].id

  security_group_ids = [
    aws_security_group.vpc_endpoints.id
  ]

  tags = {
    Name    = "${var.project_name}-secretsmanager-endpoint"
    Project = var.project_name
    Service = "secretsmanager"
    Type    = "interface"
  }
}

# -----------------------------------------------------------------------------
# Current AWS region
# -----------------------------------------------------------------------------

data "aws_region" "current" {}