variable "region" {
  description = "AWS region to create resources in"
  type        = string
  default     = "ap-southeast-2"
}

variable "repository_list" {
  description = "List of repository names"
  type        = list(any)
  default     = ["ps-backend", "ps-worker"]
}

variable "replication_regions" {
  type        = list(string)
  description = "List of replication regions"
  default     = ["us-east-1", "eu-west-1"]
}
