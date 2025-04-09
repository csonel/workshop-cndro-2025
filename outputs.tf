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

output "eks_endpoint" {
  description = "EKS Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "eks_kubeconfig_command" {
  description = "Command to configure kubectl to use the EKS cluster"
  value       = "aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_name} --profile amcloud --no-verify-ssl"
}

output "my_ip_address" {
  description = "My public IP address"
  value       = chomp(data.http.myip.response_body)
}
