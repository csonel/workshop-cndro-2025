variable "region" {
  type        = string
  description = "AWS region to deploy resources in"
  default     = "eu-central-1"
}

variable "enable_budget" {
  type        = bool
  description = "Enable budget notifications"
  default     = true
}

variable "email_address" {
  type        = string
  description = "Please enter your valid email address\nEmail address will be used to receive budget notifications"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"

  default = {
    Terraform = "true"
    Project   = "Cloud Native Days Romania 2025"
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones to use for the VPC"
}

variable "private_subnets" {
  type        = list(string)
  description = "List of private subnets to create in the VPC"
}

variable "database_subnets" {
  type        = list(string)
  description = "List of database subnets to create in the VPC"
}

variable "public_subnets" {
  type        = list(string)
  description = "List of public subnets to create in the VPC"
}

