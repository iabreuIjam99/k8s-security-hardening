# Main Terraform configuration for K8s Security Hardening
# This file orchestrates all security components

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  # Uncomment for remote state
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "k8s-security/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "k8s-security-hardening"
      ManagedBy   = "Terraform"
      Environment = var.environment
      Owner       = var.owner
    }
  }
}

# Data source for AWS availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  cluster_name = var.cluster_name
  vpc_cidr     = var.vpc_cidr
  environment  = var.environment

  availability_zones = slice(data.aws_availability_zones.available.names, 0, 3)
}

# EKS Cluster Module with security hardening
module "eks" {
  source = "./modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version
  environment     = var.environment

  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  
  # Node groups configuration
  node_groups = var.node_groups

  # Security settings
  enable_irsa                      = true
  enable_cluster_encryption        = true
  cluster_encryption_key_arn       = module.kms.cluster_encryption_key_arn
  enable_cluster_log_types         = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  
  # Network security
  cluster_endpoint_private_access  = true
  cluster_endpoint_public_access   = true
  cluster_endpoint_public_access_cidrs = var.allowed_cidr_blocks
}

# KMS Module for encryption
module "kms" {
  source = "./modules/kms"

  cluster_name = var.cluster_name
  environment  = var.environment
}

# Security Components Module
module "security" {
  source = "./modules/security"

  cluster_name           = var.cluster_name
  cluster_endpoint       = module.eks.cluster_endpoint
  cluster_ca_certificate = module.eks.cluster_certificate_authority_data

  # OPA Gatekeeper
  enable_opa_gatekeeper = var.enable_opa_gatekeeper
  
  # Falco
  enable_falco          = var.enable_falco
  falco_rules_file      = var.falco_rules_file
  
  # Monitoring
  enable_prometheus     = var.enable_prometheus
  enable_grafana        = var.enable_grafana
  
  depends_on = [module.eks]
}

# AWS Load Balancer Controller
module "aws_load_balancer_controller" {
  source = "./modules/aws-load-balancer-controller"

  cluster_name         = var.cluster_name
  cluster_oidc_issuer  = module.eks.cluster_oidc_issuer_url
  vpc_id               = module.vpc.vpc_id

  depends_on = [module.eks]
}

# External Secrets Operator for secrets management
module "external_secrets" {
  source = "./modules/external-secrets"

  cluster_name        = var.cluster_name
  cluster_oidc_issuer = module.eks.cluster_oidc_issuer_url
  environment         = var.environment

  depends_on = [module.eks]
}
