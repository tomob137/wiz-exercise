terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Where Terraform keeps its memory. Filled in on lab day 1 from backend.hcl.
  backend "s3" {}
}

provider "aws" {
  region = var.region

  # Every resource gets these tags, so you can find (and prove) what you built.
  default_tags {
    tags = {
      Project   = "wiz-exercise"
      Owner     = "thomas-obrien"
      ManagedBy = "terraform"
    }
  }
}

# A short random suffix so bucket names are globally unique.
resource "random_id" "suffix" {
  byte_length = 3
}