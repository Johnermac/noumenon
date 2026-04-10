output "state_bucket_name" {
  value       = aws_s3_bucket.terraform_state.bucket
  description = "S3 bucket storing Terraform state."
}

output "lock_table_name" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "DynamoDB table used for Terraform state locking."
}
