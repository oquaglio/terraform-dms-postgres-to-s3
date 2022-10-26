output "account_id" {
  value = "${data.aws_caller_identity.current.account_id}"
}

output "s3_bucket_name" {
  description = "Name of bucket"
  value       = module.s3_bucket.s3_bucket_id
}

output "s3_role_name" {
  description = "Name of role"
  value       = aws_iam_role.s3_role.name
}

output "dms_replication_instance_arn" {
  description = "ARN of DMS replication instance"
  value       = module.dms.replication_instance_arn
}
