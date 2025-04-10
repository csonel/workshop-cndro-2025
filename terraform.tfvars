# VPC
availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
public_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

# Cluster Autoscaler
enable_eks_cluster_autoscaler = false

# Karpenter
enable_karpenter             = false
karpenter_namespace          = "karpenter"
karpenter_service_account    = "karpenter-controller-sa"
karpenter_use_spot_instances = false
