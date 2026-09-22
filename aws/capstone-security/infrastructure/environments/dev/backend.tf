terraform {
  backend "s3" {
    # Pre-create this bucket outside this Terraform configuration.
    # The backend bucket must be private and encrypted.
    bucket = "wilsonnjoroge-terraform-state"
    key    = "aws/capstone-security/dev/terraform.tfstate"
    region = "us-east-1"

    # Native S3 state locking. Requires Terraform 1.10+.
    use_lockfile = true

    encrypt = true
  }
}


 