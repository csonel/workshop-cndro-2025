output "my-ip-address" {
  value = chomp(data.http.myip.response_body)
}

output "aws-region" {
  value = var.region
}

output "eks-endpoint" {
  value = module.eks.cluster_endpoint
}
