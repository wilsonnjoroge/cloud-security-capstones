# -----------------------------------------------------------------------------
# Web Tier
# -----------------------------------------------------------------------------

resource "aws_instance" "web" {
  count = var.web_instance_count

  ami           = var.web_ami_id
  instance_type = var.web_instance_type

  subnet_id = var.web_subnet_ids[
    count.index % length(var.web_subnet_ids)
  ]

  vpc_security_group_ids = [
    var.web_security_group_id
  ]

  iam_instance_profile = var.web_instance_profile_name

  # ---------------------------------------------------------------------------
  # IMDSv2
  # ---------------------------------------------------------------------------

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  # ---------------------------------------------------------------------------
  # Root EBS
  # ---------------------------------------------------------------------------

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.web_root_volume_size
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name    = "${var.project_name}-web-${count.index + 1}-root"
      Project = var.project_name
      Tier    = "web"
    }
  }

  tags = {
    Name    = "${var.project_name}-web-${count.index + 1}"
    Project = var.project_name
    Tier    = "web"
  }
}

# -----------------------------------------------------------------------------
# Application Tier
# -----------------------------------------------------------------------------

resource "aws_instance" "app" {
  count = var.app_instance_count

  ami           = var.app_ami_id
  instance_type = var.app_instance_type

  subnet_id = var.app_subnet_ids[
    count.index % length(var.app_subnet_ids)
  ]

  vpc_security_group_ids = [
    var.app_security_group_id
  ]

  iam_instance_profile = var.app_instance_profile_name

  # ---------------------------------------------------------------------------
  # IMDSv2
  # ---------------------------------------------------------------------------

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  # ---------------------------------------------------------------------------
  # Root EBS
  # ---------------------------------------------------------------------------

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.app_root_volume_size
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name    = "${var.project_name}-app-${count.index + 1}-root"
      Project = var.project_name
      Tier    = "app"
    }
  }

  tags = {
    Name    = "${var.project_name}-app-${count.index + 1}"
    Project = var.project_name
    Tier    = "app"
  }
}