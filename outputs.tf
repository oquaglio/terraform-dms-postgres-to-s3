output "s3_bucket_name" {
  description = "Name of bucket"
  value       = module.s3_bucket.s3_bucket_id
}

output "s3_role_name" {
  description = "Name of role"
  value       = aws_iam_role.s3_role.name
}
