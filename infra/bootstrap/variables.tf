variable "aws_region" {
  description = "AWS region for the Terraform backend resources."
  type        = string
}

variable "state_bucket_name" {
  description = "S3 bucket name used for Terraform state."
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table name used for Terraform state locking."
  type        = string
  default     = "noumenon-terraform-locks"
}

variable "tags" {
  description = "Common tags applied to bootstrap resources."
  type        = map(string)
  default = {
    Project = "noumenon"
    Managed = "terraform"
  }
}
