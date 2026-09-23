project_name = "capstone-security"
environment  = "dev"
aws_region   = "us-east-1"

availability_zones = [
  "us-east-1a",
  "us-east-1b",
]

vpc_cidr = "10.0.0.0/16"

public_subnet_cidrs = [
  "10.0.0.0/24",
  "10.0.1.0/24",
]

web_subnet_cidrs = [
  "10.0.10.0/24",
  "10.0.11.0/24",
]

app_subnet_cidrs = [
  "10.0.20.0/24",
  "10.0.21.0/24",
]

db_subnet_cidrs = [
  "10.0.30.0/24",
  "10.0.31.0/24",
]

web_listen_port = 8443
app_listen_port = 8080
db_port         = 3306
redis_port      = 6379

web_instance_type = "t3.micro"
app_instance_type = "t3.micro"

web_min_size = 2
web_max_size = 4
app_min_size = 2
app_max_size = 4

web_target_cpu = 60
app_target_cpu = 60

# Leave null to let the compute module resolve its approved Linux AMI.
web_ami_id = null
app_ami_id = null

db_instance_class          = "db.t3.micro"
db_allocated_storage       = 20
db_backup_retention_period = 7

cache_node_type = "cache.t3.micro"
cache_num_nodes = 2

flow_log_retention_days    = 30
enable_deletion_protection = true
enable_secrets_rotation    = false

ansible_bundle_key_prefix = "ansible/"

# Required for the internal ALB HTTPS listener. Supply an existing ACM
# certificate ARN in the target AWS account/region before terraform plan/apply.
# internal_alb_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
