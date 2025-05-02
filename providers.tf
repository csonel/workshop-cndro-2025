terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.83.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.4.5"
    }
  }
  backend "s3" {
    bucket       = "cndro-terraform"
    key          = "terraform.tfstate"
    region       = "eu-central-1"
    profile      = "cndro2025"
    use_lockfile = true
  }
}

provider "aws" {
  region  = var.region
  profile = "cndro2025"

  default_tags {
    tags = {
      managed-by  = "terraform"
      Project     = "Cloud Native Days Romania 2025"
      Environment = "Dev"
      Service     = "EKS"
    }
  }
}
