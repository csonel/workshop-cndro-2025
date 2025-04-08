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
