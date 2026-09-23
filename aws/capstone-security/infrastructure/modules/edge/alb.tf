locals {
  name_prefix = coalesce(var.name_prefix, substr("${var.project_name}-${var.environment}", 0, 20))
}

#tfsec:ignore:aws-elb-alb-not-public -- edge ALB is intentionally public, fronted by CloudFront+WAF
resource "aws_lb" "public" {
  name               = "${local.name_prefix}-public-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [var.public_alb_security_group_id]

  enable_deletion_protection = true
  drop_invalid_header_fields = true

  tags = {
    Name = "${local.name_prefix}-public-alb"
  }
}

resource "aws_lb_target_group" "web" {
  name        = "${local.name_prefix}-web-tg"
  port        = var.web_listen_port
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = data.aws_vpc.current.id

  health_check {
    protocol            = "HTTPS"
    path                = "/health"
    port                = tostring(var.web_listen_port)
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
}

#tfsec:ignore:aws-elb-http-not-used
resource "aws_lb_listener" "public_http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb" "internal" {
  name               = "${local.name_prefix}-int-alb"
  internal           = true
  load_balancer_type = "application"
  subnets            = var.web_subnet_ids
  security_groups    = [var.internal_alb_security_group_id]

  enable_deletion_protection = true
  drop_invalid_header_fields = true

  tags = {
    Name = "${local.name_prefix}-internal-alb"
  }
}

resource "aws_lb_target_group" "app" {
  name        = "${local.name_prefix}-app-tg"
  port        = var.app_listen_port
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = data.aws_vpc.current.id

  health_check {
    protocol            = "HTTPS"
    path                = "/health"
    port                = tostring(var.app_listen_port)
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "internal_https" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.internal_alb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

data "aws_vpc" "current" {
  id = data.aws_subnet.web.vpc_id
}

data "aws_subnet" "web" {
  id = var.web_subnet_ids[0]
}
