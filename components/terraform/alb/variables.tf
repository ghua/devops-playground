variable "remote_state_bucket_id" {
  type        = string
  description = "The remote state S3 bucket ID"
}

variable "remote_state_bucket_region" {
  type        = string
  description = "The AWS region where remote state S3 bucket is located"
}

variable "remote_state_bucket_key" {
  type        = string
  description = "The path to the state file inside the remote state S3 bucket"
}

variable "region" {
  type        = string
  description = "AWS Region"
}
