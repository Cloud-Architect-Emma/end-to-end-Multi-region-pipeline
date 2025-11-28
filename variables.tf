variable "region" {
  description = "AWS region where the backend resources will be created"
  type        = string
  default     = "eu-west-2"
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket to store Terraform remote state"
  type        = string
  default     = "tfstate-cloud-architect-emma"
}

variable "lock_table_name" {
  description = "Name of the DynamoDB table for Terraform state locking"
  type        = string
  default     = "tf-lock-cloud-architect-emma"
}
