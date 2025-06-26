#ADDED 6/26/2025
variable "public_key_path" {
  type        = string
  description = "Path to the public key file"
}

variable "instance_count" {
  description = "Number of EC2 instances to deploy"
  type        = number
}

variable "instance_type" {
  description = "Type of EC2 instance to use"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for EC2 instances"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for EC2 instances"
  type        = list(string)
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Name of the environment"
  type        = string
}
