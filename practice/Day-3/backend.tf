
terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "terraform-demo-backend-21-10-2026"
    key          = "terraform-practice/day-3/terraform.tfstate"
    region       = "us-east-1"
    profile      = "terraform-demo"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
