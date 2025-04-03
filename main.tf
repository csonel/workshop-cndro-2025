################################################################################
# Budget
################################################################################
locals {
  email_address = var.enable_budget ? var.email_address : null
}

resource "aws_budgets_budget" "cost" {
  count = var.enable_budget ? 1 : 0

  name         = "Budget"
  budget_type  = "COST"
  limit_amount = "10"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "ACTUAL"
    threshold                  = 10
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [local.email_address]
  }
}

################################################################################
# VPC
################################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name = "cndro"
  cidr = "10.0.0.0/22"

  azs              = var.availability_zones
  private_subnets  = var.private_subnets
  database_subnets = var.database_subnets
  public_subnets   = var.public_subnets

  enable_nat_gateway = true
  single_nat_gateway = true

  vpc_tags = {
    Name = "cndro-vpc"
  }

  tags = var.tags
}

################################################################################
# Kubernetes Cluster
################################################################################
data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = "cndro-eks"
  cluster_version = "1.31"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_private_access      = false
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = ["${chomp(data.http.myip.response_body)}/32"]

  cluster_tags = {
    Name = "cndro-eks"
  }

  tags = var.tags
}
