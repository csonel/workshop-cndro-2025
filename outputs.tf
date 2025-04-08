output "my_ip_address" {
  description = "My public IP address"
  value       = chomp(data.http.myip.response_body)
}

output "aws_region" {
  description = "AWS region where the resources are deployed"
  value       = var.region
}

output "eks_endpoint" {
  description = "EKS Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "eks_kubeconfig_command" {
  description = "Command to configure kubectl to use the EKS cluster"
  value       = "aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_name} --profile amcloud --no-verify-ssl"
}
