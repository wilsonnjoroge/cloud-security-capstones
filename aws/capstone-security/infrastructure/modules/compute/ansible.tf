# -----------------------------------------------------------------------------
# Ansible Inventory
# -----------------------------------------------------------------------------
# Terraform generates the inventory consumed by Ansible.
#
# AWS Systems Manager is the intended management path. No inbound SSH access
# is required for the EC2 workloads.

resource "local_file" "ansible_inventory" {
  filename = "${path.root}/../../../ansible/inventory/${var.project_name}-inventory.yml"

  content = yamlencode({
    all = {
      children = {
        web = {
          hosts = {
            for instance in aws_instance.web :
            instance.tags["Name"] => {
              instance_id = instance.id
              private_ip  = instance.private_ip
            }
          }
        }

        app = {
          hosts = {
            for instance in aws_instance.app :
            instance.tags["Name"] => {
              instance_id = instance.id
              private_ip  = instance.private_ip
            }
          }
        }
      }
    }
  })
}