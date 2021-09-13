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

variable "repositories" {
  type    = list(any)
  default = ["backend", "worker"]
}

variable "image_tag" {
  default = "latest"
}

variable "environment_variables_map" {
  description = "Map of environment variables"
  type        = map(any)
  default     = {}
}
