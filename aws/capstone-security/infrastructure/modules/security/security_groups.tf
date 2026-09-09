# -----------------------------------------------------------------------------
# Public ALB Security Group
# -----------------------------------------------------------------------------

# Looked up by name, not hardcoded — resolves to the correct prefix-list ID
# for whatever account/region this runs in. This is what scopes public ALB
# ingress to CloudFront's edge network only, instead of the open internet.
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "public_alb" {
  name        = "${var.project_name}-public-alb-sg"
  description = "Security group for the internet-facing Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from CloudFront edge network only"
    protocol        = "tcp"
    from_port       = 443
    to_port         = 443
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }

  egress {
    description = "HTTPS to web tier"
    protocol    = "tcp"
    from_port   = var.web_listen_port
    to_port     = var.web_listen_port
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name    = "${var.project_name}-public-alb-sg"
    Project = var.project_name
    Tier    = "edge"
    Role    = "public-alb"
  }
}


# -----------------------------------------------------------------------------
# Web Tier Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Security group for private web-tier EC2 instances"
  vpc_id      = var.vpc_id

  # Traffic originates from the public ALB only.
  # The public ALB SG will be referenced by the rule created below.

  ingress {
    description     = "HTTPS from public ALB"
    protocol        = "tcp"
    from_port       = var.web_listen_port
    to_port         = var.web_listen_port
    security_groups = [aws_security_group.public_alb.id]
  }

  egress {
    description = "HTTPS to internal application tier"
    protocol    = "tcp"
    from_port   = var.app_listen_port
    to_port     = var.app_listen_port
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name    = "${var.project_name}-web-sg"
    Project = var.project_name
    Tier    = "web"
    Role    = "web"
  }
}

# -----------------------------------------------------------------------------
# Internal ALB Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "internal_alb" {
  name        = "${var.project_name}-internal-alb-sg"
  description = "Security group for the internal application load balancer"
  vpc_id      = var.vpc_id


  ingress {
    description     = "HTTPS from web tier"
    protocol        = "tcp"
    from_port       = 443
    to_port         = 443
    security_groups = [aws_security_group.web.id]
  }

  egress {
    description = "HTTPS to application tier"
    protocol    = "tcp"
    from_port   = var.app_listen_port
    to_port     = var.app_listen_port
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name    = "${var.project_name}-internal-alb-sg"
    Project = var.project_name
    Tier    = "app"
    Role    = "internal-alb"
  }
}

# -----------------------------------------------------------------------------
# Application Tier Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Security group for private application-tier EC2 instances"
  vpc_id      = var.vpc_id

  # Application instances accept traffic only from the internal ALB.

  ingress {
    description     = "Application HTTPS from internal ALB"
    protocol        = "tcp"
    from_port       = var.app_listen_port
    to_port         = var.app_listen_port
    security_groups = [aws_security_group.internal_alb.id]
  }


  egress {
    description = "HTTPS to AWS services and internal endpoints"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name    = "${var.project_name}-app-sg"
    Project = var.project_name
    Tier    = "app"
    Role    = "application"
  }
}

# -----------------------------------------------------------------------------
# RDS Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for private RDS database instances"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from application tier"
    protocol        = "tcp"
    from_port       = var.db_port
    to_port         = var.db_port
    security_groups = [aws_security_group.app.id]
  }

  # No unrestricted ingress.
  # No explicit internet egress is required for the database tier.

  tags = {
    Name    = "${var.project_name}-rds-sg"
    Project = var.project_name
    Tier    = "db"
    Role    = "rds"
  }
}

# -----------------------------------------------------------------------------
# Redis / Valkey Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "redis" {
  name        = "${var.project_name}-redis-sg"
  description = "Security group for private Redis/Valkey cache"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis from application tier"
    protocol        = "tcp"
    from_port       = var.redis_port
    to_port         = var.redis_port
    security_groups = [aws_security_group.app.id]
  }

  tags = {
    Name    = "${var.project_name}-redis-sg"
    Project = var.project_name
    Tier    = "db"
    Role    = "redis"
  }
}

# -----------------------------------------------------------------------------
# VPC Endpoint Security Group
# -----------------------------------------------------------------------------
# The network module already creates the endpoint SG because interface
# endpoints belong to the network boundary. This module therefore does not
# create or reference that SG.
#
# Endpoint traffic is intentionally kept separate from workload SGs.