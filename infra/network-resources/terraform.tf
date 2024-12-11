terraform {
  backend "remote" {
    organization = "Adeolus_Private_Lab"
    
    workspaces {
      name = "bgd-dpl-dev-infra"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}