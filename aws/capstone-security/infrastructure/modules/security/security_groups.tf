data "aws_ec2_managed_prefix_list" "cloudfront_origin_facing" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# Security group containers intentionally contain no inline rules. Rules are
# managed separately so Terraform does not create a dependency cycle between
# the tier security groups.
resource "aws_security_group" "public_alb" {
  name        = "${local.name_prefix}-public-alb-sg"
  description = "Public ALB: CloudFront origin-facing prefix list only."
  vpc_id      = var.vpc_id

  tags = { Name = "${local.name_prefix}-public-alb-sg" }
}

resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "Private web tier trust boundary."
  vpc_id      = var.vpc_id

  tags = { Name = "${local.name_prefix}-web-sg" }
}

resource "aws_security_group" "internal_alb" {
  name        = "${local.name_prefix}-internal-alb-sg"
  description = "Internal ALB: web tier ingress only."
  vpc_id      = var.vpc_id

  tags = { Name = "${local.name_prefix}-internal-alb-sg" }
}

resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app-sg"
  description = "Private application tier trust boundary."
  vpc_id      = var.vpc_id

  tags = { Name = "${local.name_prefix}-app-sg" }
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "RDS ingress from app tier only."
  vpc_id      = var.vpc_id

  tags = { Name = "${local.name_prefix}-rds-sg" }
}

resource "aws_security_group" "redis" {
  name        = "${local.name_prefix}-redis-sg"
  description = "Redis ingress from app tier only."
  vpc_id      = var.vpc_id

  tags = { Name = "${local.name_prefix}-redis-sg" }
}

# CloudFront -> public ALB. HTTP is deliberate for the current lab because
# there is no owned public domain/origin certificate yet.
resource "aws_vpc_security_group_ingress_rule" "public_alb_cloudfront_http" {
  security_group_id = aws_security_group.public_alb.id
  description       = "CloudFront origin-facing HTTP"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront_origin_facing.id
}

# Public ALB -> web tier HTTPS.
resource "aws_vpc_security_group_egress_rule" "public_alb_to_web" {
  security_group_id            = aws_security_group.public_alb.id
  description                  = "Public ALB to web tier TLS"
  from_port                    = var.web_listen_port
  to_port                      = var.web_listen_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.web.id
}

resource "aws_vpc_security_group_ingress_rule" "web_from_public_alb" {
  security_group_id            = aws_security_group.web.id
  description                  = "TLS from public ALB"
  from_port                    = var.web_listen_port
  to_port                      = var.web_listen_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.public_alb.id
}

# Web -> internal ALB HTTPS.
resource "aws_vpc_security_group_egress_rule" "web_to_internal_alb" {
  security_group_id            = aws_security_group.web.id
  description                  = "TLS to internal ALB"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.internal_alb.id
}

resource "aws_vpc_security_group_ingress_rule" "internal_alb_from_web" {
  security_group_id            = aws_security_group.internal_alb.id
  description                  = "HTTPS from web tier"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.web.id
}

# Internal ALB -> app tier HTTPS.
resource "aws_vpc_security_group_egress_rule" "internal_alb_to_app" {
  security_group_id            = aws_security_group.internal_alb.id
  description                  = "TLS to app tier"
  from_port                    = var.app_listen_port
  to_port                      = var.app_listen_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_ingress_rule" "app_from_internal_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "TLS from internal ALB"
  from_port                    = var.app_listen_port
  to_port                      = var.app_listen_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.internal_alb.id
}

# App -> RDS MySQL.
resource "aws_vpc_security_group_egress_rule" "app_to_rds" {
  security_group_id            = aws_security_group.app.id
  description                  = "MySQL to RDS"
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.rds.id
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_app" {
  security_group_id            = aws_security_group.rds.id
  description                  = "MySQL from app tier"
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}

# App -> Redis.
resource "aws_vpc_security_group_egress_rule" "app_to_redis" {
  security_group_id            = aws_security_group.app.id
  description                  = "Redis to ElastiCache"
  from_port                    = var.redis_port
  to_port                      = var.redis_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.redis.id
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_app" {
  security_group_id            = aws_security_group.redis.id
  description                  = "Redis from app tier"
  from_port                    = var.redis_port
  to_port                      = var.redis_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}

# Web/App -> private AWS interface endpoints.
resource "aws_vpc_security_group_egress_rule" "web_to_vpc_endpoints" {
  security_group_id            = aws_security_group.web.id
  description                  = "HTTPS to private AWS service endpoints"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.vpc_endpoint_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "app_to_vpc_endpoints" {
  security_group_id            = aws_security_group.app.id
  description                  = "HTTPS to private AWS service endpoints"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.vpc_endpoint_security_group_id
}
