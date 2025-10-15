# KMS Module for Kubernetes encryption

resource "aws_kms_key" "eks" {
  description             = "EKS Cluster ${var.cluster_name} encryption key"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name = "${var.cluster_name}-eks-encryption-key"
  }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}
