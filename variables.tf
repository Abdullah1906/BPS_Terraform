variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "project_name" {
  type    = string
  default = "bps"
}

variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "public_subnet_1_cidr" {
  type    = string
  default = "10.10.1.0/24"
}

variable "public_subnet_2_cidr" {
  type    = string
  default = "10.10.2.0/24"
}

variable "private_subnet_1_cidr" {
  type    = string
  default = "10.10.11.0/24"
}

variable "private_subnet_2_cidr" {
  type    = string
  default = "10.10.12.0/24"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "sql_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "sql_ubuntu_version" {
  type    = string
  default = "22.04"
}

variable "sql_storage_gb" {
  type    = number
  default = 100
}

variable "min_size" {
  type    = number
  default = 2
}

variable "desired_capacity" {
  type    = number
  default = 2
}

variable "max_size" {
  type    = number
  default = 4
}

variable "app_port" {
  type    = number
  default = 5000
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "github_org" {
  type        = string
  description = "GitHub organization/user that owns the repository."
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name, without owner."
}

variable "github_branch" {
  type    = string
  default = "main"
}
