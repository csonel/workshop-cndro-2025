terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.83.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">=3.4.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.13.0"
    }
  }
  backend "s3" {
    bucket  = "cndro-terraform"
    key     = "terraform.tfstate"
    region  = "eu-central-1"
    profile = "amcloud"
  }
}

provider "aws" {
  region  = var.region
  profile = "amcloud"
}