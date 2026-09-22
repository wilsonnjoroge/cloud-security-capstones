data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  web_ami     = coalesce(var.web_ami_id, data.aws_ssm_parameter.al2023.value)
  app_ami     = coalesce(var.app_ami_id, data.aws_ssm_parameter.al2023.value)
}

# Web instances are private and managed through SSM; SSH is intentionally absent.
resource "aws_launch_template" "web" {
  name_prefix   = "${local.name_prefix}-web-"
  image_id      = local.web_ami
  instance_type = var.web_instance_type

  iam_instance_profile {
    name = var.web_instance_profile_name
  }

  vpc_security_group_ids = [var.web_security_group_id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.ebs_kms_key_arn
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name_prefix}-web"
      Role = "web"
    }
  }
}

resource "aws_autoscaling_group" "web" {
  name                = "${local.name_prefix}-web-asg"
  min_size            = var.web_min_size
  max_size            = var.web_max_size
  desired_capacity    = var.web_min_size
  vpc_zone_identifier = var.web_subnet_ids
  health_check_type   = "ELB"

  target_group_arns = [var.web_target_group_arn]

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Role"
    value               = "web"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "web_cpu" {
  name                   = "${local.name_prefix}-web-cpu-target"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name  = aws_autoscaling_group.web.name
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.web_target_cpu
  }
}

# App instances are private and managed through SSM; SSH is intentionally absent.
resource "aws_launch_template" "app" {
  name_prefix   = "${local.name_prefix}-app-"
  image_id      = local.app_ami
  instance_type = var.app_instance_type

  iam_instance_profile {
    name = var.app_instance_profile_name
  }

  vpc_security_group_ids = [var.app_security_group_id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.ebs_kms_key_arn
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name_prefix}-app"
      Role = "app"
    }
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${local.name_prefix}-app-asg"
  min_size            = var.app_min_size
  max_size            = var.app_max_size
  desired_capacity    = var.app_min_size
  vpc_zone_identifier = var.app_subnet_ids
  health_check_type   = "ELB"

  target_group_arns = [var.app_target_group_arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Role"
    value               = "app"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "app_cpu" {
  name                  = "${local.name_prefix}-app-cpu-target"
  policy_type           = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.app.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.app_target_cpu
  }
}
