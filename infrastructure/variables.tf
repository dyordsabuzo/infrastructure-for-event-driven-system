variable "region" {
  description = "AWS region to create resources in"
  type        = string
  default     = "ap-southeast-2"
}

variable "repository_list" {
  description = "List of repository names"
  type        = list(any)
  default     = ["backend", "worker"]
}

variable "backend_container_port" {
  type        = number
  description = "Backend container port"
  default     = 8000
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "max_instance_count" {
  type        = number
  description = "Max instance count in auto scaling group"
  default     = 2
}

variable "environment_variables_map" {
  type        = map(any)
  description = "Map of environment variables"
  default     = {}
}

variable "hosted_zone_name" {
  type        = string
  description = "Route 53 hosted zone"
}

variable "endpoint_name" {
  type        = string
  description = "Route 53 record name"
}

variable "vpc_id" {
  type        = string
  description = "VPC id"
  default     = null
}

variable "private_subnets" {
  type        = list(string)
  description = "List of private subnets"
  default     = []
}

variable "public_subnets" {
  type        = list(string)
  description = "List of public subnets"
  default     = []
}

variable "instance_security_groups" {
  type        = list(string)
  description = "List of instance security groups"
  default     = []
}

variable "lb_security_groups" {
  type        = list(string)
  description = "List of load balancer security groups"
  default     = []
}
