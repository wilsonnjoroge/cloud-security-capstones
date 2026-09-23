locals {
  name_prefix = "${var.project_name}-${var.environment}"

  public_subnets = {
    for index, cidr in var.public_subnet_cidrs : index => {
      cidr = cidr
      az   = var.availability_zones[index]
    }
  }

  web_subnets = {
    for index, cidr in var.web_subnet_cidrs : index => {
      cidr = cidr
      az   = var.availability_zones[index]
    }
  }

  app_subnets = {
    for index, cidr in var.app_subnet_cidrs : index => {
      cidr = cidr
      az   = var.availability_zones[index]
    }
  }

  db_subnets = {
    for index, cidr in var.db_subnet_cidrs : index => {
      cidr = cidr
      az   = var.availability_zones[index]
    }
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_flow_log" "this" {
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn
}


resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${local.name_prefix}-flow-logs"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.s3_logs.arn
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "${local.name_prefix}-vpc-flow-logs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

#tfsec:ignore:aws-iam-no-policy-wildcards -- CloudWatch Logs stream-level actions require the trailing :* on the log group ARN; scope is already limited to this specific log group
resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${local.name_prefix}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
    }]
  })
}


resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-public-${each.key + 1}"
    Tier = "public"
  }
}

resource "aws_subnet" "web" {
  for_each = local.web_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = "${local.name_prefix}-web-${each.key + 1}"
    Tier = "web"
  }
}

resource "aws_subnet" "app" {
  for_each = local.app_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = "${local.name_prefix}-app-${each.key + 1}"
    Tier = "app"
  }
}

resource "aws_subnet" "db" {
  for_each = local.db_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = "${local.name_prefix}-db-${each.key + 1}"
    Tier = "db"
  }
}

resource "aws_eip" "nat" {
  for_each = var.enable_nat_gateway ? toset(["0", "1"]) : toset([])

  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip-${each.key}"
  }
}

resource "aws_nat_gateway" "this" {
  for_each = var.enable_nat_gateway ? toset(["0", "1"]) : toset([])

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[tonumber(each.key)].id

  depends_on = [aws_internet_gateway.this]

  tags = {
    Name = "${local.name_prefix}-nat-${tonumber(each.key) + 1}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "web" {
  for_each = toset(["0", "1"])

  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[each.key].id
    }
  }

  tags = {
    Name = "${local.name_prefix}-web-rt-${tonumber(each.key) + 1}"
  }
}

resource "aws_route_table_association" "web" {
  for_each = aws_subnet.web

  subnet_id      = each.value.id
  route_table_id = aws_route_table.web[each.key].id
}

resource "aws_route_table" "app" {
  for_each = toset(["0", "1"])

  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[each.key].id
    }
  }

  tags = {
    Name = "${local.name_prefix}-app-rt-${tonumber(each.key) + 1}"
  }
}

resource "aws_route_table_association" "app" {
  for_each = aws_subnet.app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.app[each.key].id
}

# DB subnets intentionally receive only the implicit VPC-local route.
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-db-isolated-rt"
  }
}

resource "aws_route_table_association" "db" {
  for_each = aws_subnet.db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.db.id
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.name_prefix}-db-subnets"
  subnet_ids = [for subnet in aws_subnet.db : subnet.id]

  tags = {
    Name = "${local.name_prefix}-db-subnet-group"
  }
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${local.name_prefix}-cache-subnets"
  subnet_ids = [for subnet in aws_subnet.db : subnet.id]
}
