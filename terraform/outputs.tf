# Outputs for Kubernetes Security Hardening Infrastructure

output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "vpc_id" {
  description = "VPC ID where cluster is deployed"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "kms_key_arn" {
  description = "ARN of KMS key used for cluster encryption"
  value       = module.kms.cluster_encryption_key_arn
}

output "grafana_url" {
  description = "URL to access Grafana dashboard"
  value       = var.enable_grafana ? "Run: kubectl port-forward -n monitoring svc/grafana 3000:80" : "Grafana not enabled"
}

output "prometheus_url" {
  description = "URL to access Prometheus"
  value       = var.enable_prometheus ? "Run: kubectl port-forward -n monitoring svc/prometheus-server 9090:80" : "Prometheus not enabled"
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}
