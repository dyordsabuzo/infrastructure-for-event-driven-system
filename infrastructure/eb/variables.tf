variable "region" {
  description = "AWS region to create resources in"
  type        = string
  default     = "ap-southeast-2"
}

variable "backend_image" {
  description = "Backend image"
  type        = string
  default     = "backend:latest"
}

variable "worker_image" {
  description = "Worker image"
  type        = string
  default     = "worker:latest"
}
