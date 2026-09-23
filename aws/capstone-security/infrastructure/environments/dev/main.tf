locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

module "network" {
  source = "../../modules/network"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  public_subnet_cidrs = var.public_subnet_cidrs
  web_subnet_cidrs    = var.web_subnet_cidrs
  app_subnet_cidrs    = var.app_subnet_cidrs
  db_subnet_cidrs     = var.db_subnet_cidrs

  enable_nat_gateway = true
}

module "security" {
  source = "../../modules/security"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.network.vpc_id
  vpc_cidr     = module.network.vpc_cidr

  vpc_endpoint_security_group_id = module.network.vpc_endpoint_security_group_id

  web_listen_port = var.web_listen_port
  app_listen_port = var.app_listen_port
  db_port         = var.db_port
  redis_port      = var.redis_port
}

module "edge" {
  source = "../../modules/edge"

  project_name = var.project_name
  environment  = var.environment

  public_subnet_ids = module.network.public_subnet_ids
  web_subnet_ids    = module.network.web_subnet_ids

  public_alb_security_group_id   = module.security.public_alb_security_group_id
  internal_alb_security_group_id = module.security.internal_alb_security_group_id

  web_listen_port              = var.web_listen_port
  app_listen_port              = var.app_listen_port
  internal_alb_certificate_arn = var.internal_alb_certificate_arn
}

module "compute" {
  source = "../../modules/compute"

  project_name = var.project_name
  environment  = var.environment

  web_subnet_ids = module.network.web_subnet_ids
  app_subnet_ids = module.network.app_subnet_ids

  web_security_group_id = module.security.web_security_group_id
  app_security_group_id = module.security.app_security_group_id

  web_instance_profile_name = module.security.web_instance_profile_name
  app_instance_profile_name = module.security.app_instance_profile_name

  ebs_kms_key_arn     = module.security.ebs_kms_key_arn
  ansible_kms_key_arn = module.security.ansible_bundle_kms_key_arn

  web_target_group_arn = module.edge.web_target_group_arn
  app_target_group_arn = module.edge.app_target_group_arn

  web_instance_type = var.web_instance_type
  app_instance_type = var.app_instance_type
  web_ami_id        = var.web_ami_id
  app_ami_id        = var.app_ami_id

  web_min_size = var.web_min_size
  web_max_size = var.web_max_size
  app_min_size = var.app_min_size
  app_max_size = var.app_max_size

  web_target_cpu = var.web_target_cpu
  app_target_cpu = var.app_target_cpu

  ansible_bundle_key_prefix = var.ansible_bundle_key_prefix
}

module "data" {
  source = "../../modules/data"

  project_name = var.project_name
  environment  = var.environment

  db_subnet_group_name    = module.network.db_subnet_group_name
  cache_subnet_group_name = module.network.cache_subnet_group_name

  rds_security_group_id   = module.security.rds_security_group_id
  redis_security_group_id = module.security.redis_security_group_id

  rds_kms_key_arn         = module.security.rds_kms_key_arn
  elasticache_kms_key_arn = module.security.elasticache_kms_key_arn
  secrets_kms_key_arn     = module.security.secrets_kms_key_arn

  db_port                    = var.db_port
  db_instance_class          = var.db_instance_class
  db_allocated_storage       = var.db_allocated_storage
  db_backup_retention_period = var.db_backup_retention_period

  cache_node_type = var.cache_node_type
  cache_num_nodes = var.cache_num_nodes

  enable_deletion_protection = var.enable_deletion_protection
}

module "observability" {
  source = "../../modules/observability"

  project_name = var.project_name
  environment  = var.environment

  vpc_id                  = module.network.vpc_id
  flow_logs_kms_key_arn   = module.security.flow_logs_kms_key_arn
  flow_log_retention_days = var.flow_log_retention_days
}

# The environment layer intentionally contains no aws_* resources of its own.
# It only wires explicit module outputs to module inputs.
