################################################################################
# Budget
################################################################################
locals {
  email_address = var.enable_budget ? var.email_address : null

  notifications = [
    for threshold in [10, 50, 80, 90, 92, 94, 96, 98, 100] : {
      comparison_operator = "GREATER_THAN"
      threshold           = threshold
    }
  ]
}

resource "aws_budgets_budget" "cost" {
  count = var.enable_budget ? 1 : 0

  name         = "Budget"
  budget_type  = "COST"
  limit_amount = "10"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = local.notifications
    content {
      comparison_operator        = notification.value.comparison_operator
      notification_type          = "ACTUAL"
      threshold                  = notification.value.threshold
      threshold_type             = "PERCENTAGE"
      subscriber_email_addresses = [local.email_address]
    }
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

  azs                     = var.availability_zones
  public_subnets          = var.public_subnets
  map_public_ip_on_launch = true

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

resource "aws_key_pair" "eks_nodes_remote_access" {
  key_name   = "cndro-key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHTjIfMvcfzjx0VwBMLrqA6g6g/wKqVUj4dNsQgHuBE9"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.eks_cluster_name
  cluster_version = var.eks_cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = ["${chomp(data.http.myip.response_body)}/32"]

  # Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  # Cluster addons
  cluster_addons = {
    vpc-cni = {}
    kube-proxy = {}
    coredns = {}
    metrics-server = {}
  }

  # EKS Managed Node group(s)
  eks_managed_node_group_defaults = {
    ami_type                   = "AL2023_x86_64_STANDARD"
    instance_types             = ["t3.micro", "t2.micro"]
    use_custom_launch_template = false

    remote_access = {
      ec2_ssh_key = aws_key_pair.eks_nodes_remote_access.key_name
    }

    tags = {
      Name = "cndro-eks-nodes"
    }
  }

  eks_managed_node_groups = {
    # Node group for x86_64 architecture
    eks_nodes = {
      min_size     = 1
      max_size     = 3
      desired_size = 1
    }
    # Node group for ARM64 architecture
    # arm64_nodes = {
    #   ami_type       = "AL2023_ARM_64_STANDARD"
    #   instance_types = ["t4g.micro", "t4g.small"]
    #   min_size       = 1
    #   max_size       = 3
    #   desired_size   = 1
    # }
  }

  cluster_tags = {
    Name = var.eks_cluster_name
  }

  tags = var.tags
}
