# Gateway endpoint for S3. It is attached to every route table so workloads
# can use S3 without requiring an internet path.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [aws_route_table.public.id],
    [for rt in aws_route_table.web : rt.id],
    [for rt in aws_route_table.app : rt.id]
  )

  tags = {
    Name = "${local.name_prefix}-s3-endpoint"
  }
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.name_prefix}-vpc-endpoints-sg"
  description = "HTTPS access to private AWS service interface endpoints."
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from VPC workloads"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "HTTPS to AWS service endpoints"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${local.name_prefix}-vpc-endpoints-sg"
  }
}

locals {
  interface_endpoint_services = {
    ssm            = "ssm"
    ssmmessages    = "ssmmessages"
    ec2messages    = "ec2messages"
    secretsmanager = "secretsmanager"
    logs           = "logs"
  }
}

# Interface endpoints are placed in the web subnets, one per AZ. The app tier
# reaches the endpoint ENIs over the VPC-local network and is authorized by the
# dedicated endpoint security group.
resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoint_services

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for subnet in aws_subnet.web : subnet.id]
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "${local.name_prefix}-${each.key}-endpoint"
  }
}

data "aws_region" "current" {}
