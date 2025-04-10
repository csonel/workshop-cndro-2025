output "aws_region" {
  description = "AWS region where the resources are deployed"
  value       = var.region
}

output "eks_cluster_autoscaler_role_arn" {
  description = "EKS Cluster Autoscaler Role ARN"
  value       = var.enable_eks_cluster_autoscaler ? aws_iam_role.eks_cluster_autoscaler[0].arn : "EKS Cluster Autoscaler is not enabled"
}

output "eks_cluster_name" {
  description = "EKS Cluster Name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "eks_kubeconfig_command" {
  description = "Command to configure kubectl to use the EKS cluster"
  value       = "aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_name} --profile amcloud --no-verify-ssl"
}

output "karpenter_namespace" {
  description = "Karpenter Namespace"
  value       = var.enable_karpenter ? var.karpenter_namespace : "Karpenter is not enabled"
}

output "karpenter_role_arn" {
  description = "Karpenter Role ARN"
  value       = var.enable_karpenter ? module.karpenter[0].iam_role_arn : "Karpenter is not enabled"
}

output "karpenter_service_account_name" {
  description = "Karpenter Service Account Name"
  value       = var.enable_karpenter ? var.karpenter_service_account : "Karpenter is not enabled"
}

output "karpenter_interuption_queue_name" {
  description = "Karpenter Interruption Queue Name"
  value       = var.enable_karpenter && var.karpenter_use_spot_instances ? module.karpenter.queue_name : ""
}

output "my_ip_address" {
  description = "My public IP address"
  value       = chomp(data.http.myip.response_body)
}
