output "cluster_encryption_key_arn" {
  description = "ARN of the KMS key for cluster encryption"
  value       = aws_kms_key.eks.arn
}

output "cluster_encryption_key_id" {
  description = "ID of the KMS key for cluster encryption"
  value       = aws_kms_key.eks.key_id
}
