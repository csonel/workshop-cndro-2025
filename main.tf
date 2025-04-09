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
}

################################################################################
# Kubernetes Cluster
################################################################################
data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
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
    kube-proxy = {
      addon_version = "v1.31.3-eksbuild.2"
    }
    coredns = {
      configuration_values = jsonencode({
        replicaCount = 1
        resources = {
          requests = {
            cpu    = "50m"
            memory = "25Mi"
          }
          limits = {
            cpu    = "50m"
            memory = "25Mi"
          }
        }
      })
    }
    metrics-server = {
      configuration_values = "{\"replicas\": 1}"
    }
  }

  # EKS Managed Node group(s)
  eks_managed_node_group_defaults = {
    ami_type                   = "BOTTLEROCKET_x86_64"
    instance_types             = ["t3.micro", "t2.micro"]
    use_custom_launch_template = false

    labels = {
      "managed-by" = "eks"
    }

    tags = {
      Name = "cndro-eks-nodes"
    }
  }

  eks_managed_node_groups = {
    # Node group for x86_64 architecture
    eks_nodes = {
      min_size     = 1
      max_size     = 9
      desired_size = 3
    }
    # Node group for ARM64 architecture
    # arm64_nodes = {
    #   ami_type       = "BOTTLEROCKET_ARM_64"
    #   instance_types = ["t4g.micro", "t4g.small"]
    #   min_size       = 1
    #   max_size       = 3
    #   desired_size   = 1
    # }
  }

  cluster_tags = {
    Name = var.eks_cluster_name
  }
}

resource "null_resource" "generate_kubeconfig" {
  provisioner "local-exec" {
    command = "aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_name} --profile amcloud --no-verify-ssl"
  }

  depends_on = [module.eks]
}

####################################################################
#IAM Role for Cluster Autoscaler
####################################################################
resource "aws_iam_policy" "eks_cluster_autoscaler" {
  count = var.enable_eks_cluster_autoscaler ? 1 : 0

  name        = "${module.eks.cluster_name}-cluster-autoscaler"
  description = "IAM Policy for cluster-autoscaler operator"
  path        = "/"

  policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "eks:DescribeNodegroup",
            "ec2:GetInstanceTypesFromInstanceRequirements",
            "ec2:DescribeLaunchTemplateVersions",
            "ec2:DescribeInstanceTypes",
            "ec2:DescribeImages",
            "autoscaling:DescribeTags",
            "autoscaling:DescribeScalingActivities",
            "autoscaling:DescribeLaunchConfigurations",
            "autoscaling:DescribeAutoScalingInstances",
            "autoscaling:DescribeAutoScalingGroups",
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "autoscaling:UpdateAutoScalingGroup",
            "autoscaling:TerminateInstanceInAutoScalingGroup",
            "autoscaling:SetDesiredCapacity",
          ]
          Resource = "*"
          Condition = {
            StringEqualsIfExists = {
              "autoscaling:ResourceTag/kubernetes.io/ckuster/${module.eks.cluster_name}" = "owned"
            }
          }
        },
      ]
    }
  )

  depends_on = [module.eks]
}

resource "aws_iam_role" "eks_cluster_autoscaler" {
  count = var.enable_eks_cluster_autoscaler ? 1 : 0

  name        = "${module.eks.cluster_name}-cluster-autoscaler"
  description = "IRSA for cluster-autoscaler operator"
  path        = "/"

  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Principal = {
            Federated = module.eks.oidc_provider_arn
          }
          Action = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = {
              "${replace(module.eks.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
              "${replace(module.eks.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler-sa"
            }
          }
        },
      ]
    }
  )

  depends_on = [module.eks]
}

resource "aws_iam_role_policy_attachment" "eks_cluster_autoscaler" {
  count = var.enable_eks_cluster_autoscaler ? 1 : 0

  policy_arn = aws_iam_policy.eks_cluster_autoscaler[0].arn
  role       = aws_iam_role.eks_cluster_autoscaler[0].name

  depends_on = [module.eks]
}
