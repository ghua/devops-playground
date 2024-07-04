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

variable "mysql_version" {
  type        = string
  description = "MySQL server version"
  default = "8.0"
}

variable "mysql_password" {
  type        = string
  description = "MySQL root password"
}

variable "region" {
  type        = string
  description = "AWS Region"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones"
}
