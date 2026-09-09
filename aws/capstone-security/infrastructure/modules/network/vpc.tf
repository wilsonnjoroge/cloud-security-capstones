# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

resource "aws_vpc" "capstone" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

resource "aws_internet_gateway" "capstone" {
  vpc_id = aws_vpc.capstone.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# Public subnets
# -----------------------------------------------------------------------------
# Public subnets are used for NAT Gateway placement.
# Workload instances are not deployed directly into these subnets.

resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.capstone.id
  availability_zone       = var.availability_zones[count.index]
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name    = "${var.project_name}-public-${var.availability_zones[count.index]}"
    Project = var.project_name
    Tier    = "public"
  }
}

# -----------------------------------------------------------------------------
# Web tier subnets
# -----------------------------------------------------------------------------

resource "aws_subnet" "web" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.capstone.id
  availability_zone = var.availability_zones[count.index]
  cidr_block        = var.web_subnet_cidrs[count.index]

  tags = {
    Name    = "${var.project_name}-web-${var.availability_zones[count.index]}"
    Project = var.project_name
    Tier    = "web"
  }
}

# -----------------------------------------------------------------------------
# Application tier subnets
# -----------------------------------------------------------------------------

resource "aws_subnet" "app" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.capstone.id
  availability_zone = var.availability_zones[count.index]
  cidr_block        = var.app_subnet_cidrs[count.index]

  tags = {
    Name    = "${var.project_name}-app-${var.availability_zones[count.index]}"
    Project = var.project_name
    Tier    = "app"
  }
}

# -----------------------------------------------------------------------------
# Database tier subnets
# -----------------------------------------------------------------------------
# These subnets intentionally have no internet egress route.

resource "aws_subnet" "db" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.capstone.id
  availability_zone = var.availability_zones[count.index]
  cidr_block        = var.db_subnet_cidrs[count.index]

  tags = {
    Name    = "${var.project_name}-db-${var.availability_zones[count.index]}"
    Project = var.project_name
    Tier    = "db"
  }
}

# -----------------------------------------------------------------------------
# Public routing
# -----------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.capstone.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.capstone.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
    Tier    = "public"
  }
}

resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# NAT Gateways
# -----------------------------------------------------------------------------
# One NAT Gateway per AZ provides AZ-local private-tier egress.

resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = {
    Name    = "${var.project_name}-nat-eip-${var.availability_zones[count.index]}"
    Project = var.project_name
  }
}

resource "aws_nat_gateway" "nat" {
  count = length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [
    aws_internet_gateway.capstone
  ]

  tags = {
    Name    = "${var.project_name}-nat-${var.availability_zones[count.index]}"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# Web tier routing
# -----------------------------------------------------------------------------

resource "aws_route_table" "web" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.capstone.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name    = "${var.project_name}-web-rt-${var.availability_zones[count.index]}"
    Project = var.project_name
    Tier    = "web"
  }
}

resource "aws_route_table_association" "web" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.web[count.index].id
  route_table_id = aws_route_table.web[count.index].id
}

# -----------------------------------------------------------------------------
# Application tier routing
# -----------------------------------------------------------------------------

resource "aws_route_table" "app" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.capstone.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name    = "${var.project_name}-app-rt-${var.availability_zones[count.index]}"
    Project = var.project_name
    Tier    = "app"
  }
}

resource "aws_route_table_association" "app" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}

# -----------------------------------------------------------------------------
# Database tier routing
# -----------------------------------------------------------------------------
# The database tier has only the implicit VPC-local route.
# There is intentionally no 0.0.0.0/0 route.

resource "aws_route_table" "db" {
  vpc_id = aws_vpc.capstone.id

  tags = {
    Name    = "${var.project_name}-db-rt"
    Project = var.project_name
    Tier    = "db"
  }
}

resource "aws_route_table_association" "db" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}

# -----------------------------------------------------------------------------
# RDS subnet group
# -----------------------------------------------------------------------------

resource "aws_db_subnet_group" "capstone" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.db[*].id

  tags = {
    Name    = "${var.project_name}-db-subnet-group"
    Project = var.project_name
    Tier    = "db"
  }
}

# -----------------------------------------------------------------------------
# ElastiCache subnet group
# -----------------------------------------------------------------------------

resource "aws_elasticache_subnet_group" "capstone" {
  name       = "${var.project_name}-cache-subnet-group"
  subnet_ids = aws_subnet.db[*].id

  tags = {
    Name    = "${var.project_name}-cache-subnet-group"
    Project = var.project_name
    Tier    = "db"
  }
}