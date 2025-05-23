variable "region" {
  type        = string
  description = "AWS region to deploy resources in"
  default     = "eu-central-1"
}

variable "enable_budget" {
  type        = bool
  description = "Enable budget notifications"
  default     = true
}

variable "email_address" {
  type        = string
  description = "Please enter your valid email address\nEmail address will be used to receive budget notifications"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones to use for the VPC"
}

variable "public_subnets" {
  type        = list(string)
  description = "List of public subnets to create in the VPC"
}

variable "eks_cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
  default     = "cndro-eks"
}

variable "eks_cluster_version" {
  type        = string
  description = "Version of the EKS cluster"
  default     = "1.31"
}

variable "enable_eks_cluster_autoscaler" {
  type        = bool
  description = "Create EKS Cluster Autoscaler role and policy"
  default     = true
}

variable "enable_karpenter" {
  type        = bool
  description = "Create Karpenter role and policy"
  default     = false
}

variable "karpenter_namespace" {
  type        = string
  description = "Karpenter namespace"
  default     = "karpenter"
}

variable "karpenter_service_account" {
  type        = string
  description = "Karpenter service account"
  default     = "karpenter"
}

variable "karpenter_use_spot_instances" {
  type        = bool
  description = "Use spot instances in Karpenter"
  default     = false
}
